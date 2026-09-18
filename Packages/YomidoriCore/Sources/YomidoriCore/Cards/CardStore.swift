import Foundation

/// Keeps the cards. One card per word; keeping a word already kept adds a sighting.
public protocol CardStore {
    func cards() -> [Card]
    func card(headword: String, reading: String) -> Card?
    /// Adds the sighting to the word's card, creating the card if there is none, and
    /// returns the card as it now stands.
    @discardableResult
    func keep(_ sighting: Sighting, headword: String, reading: String, entryID: Int?) throws -> Card
    func remove(_ card: Card) throws
    /// Replaces the card with the same id, as after a review.
    func update(_ card: Card) throws
}

/// One question of one card, in the review queue.
public struct ReviewItem: Hashable, Sendable {
    public let card: Card
    public let question: Question

    public init(card: Card, question: Question) {
        self.card = card
        self.question = question
    }
}

extension CardStore {
    /// The cards due at `date`, the longest overdue first, then the oldest.
    public func due(at date: Date) -> [Card] {
        cards().filter { $0.isDue(at: date) }
            .sorted { ($0.review?.due ?? $0.created) < ($1.review?.due ?? $1.created) }
    }

    /// Every question due at `date`, the longest overdue first; a card asking both
    /// contributes two items, the reading before the meaning.
    public func dueItems(at date: Date) -> [ReviewItem] {
        cards().flatMap { card in
            card.dueQuestions(at: date).map { ReviewItem(card: card, question: $0) }
        }
        .sorted {
            ($0.card.state(for: $0.question)?.due ?? $0.card.created)
                < ($1.card.state(for: $1.question)?.due ?? $1.card.created)
        }
    }
}

/// The cards as one JSON document, written whole and atomically on every change.
/// A reader's cards number in the hundreds or low thousands, which a single file
/// reads in a blink, and one file is what a sync or a backup copies. Everything
/// local, nothing leaves the device.
public final class FileCardStore: CardStore {
    private let url: URL
    private var loaded: [Card]?
    private let queue = DispatchQueue(label: "fi.misaki.yomidori.cards")

    /// The store at `url`, created empty on first write if the file does not exist.
    public init(url: URL) {
        self.url = url
    }

    /// The app's store, in Application Support.
    public static func inApplicationSupport(fileManager: FileManager = .default) throws
        -> FileCardStore
    {
        let directory = try fileManager.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil,
            create: true)
        return FileCardStore(url: directory.appendingPathComponent("cards.json"))
    }

    public func cards() -> [Card] {
        queue.sync { all() }
    }

    public func card(headword: String, reading: String) -> Card? {
        queue.sync { all().first { $0.headword == headword && $0.reading == reading } }
    }

    public func keep(_ sighting: Sighting, headword: String, reading: String, entryID: Int?) throws
        -> Card
    {
        try queue.sync {
            var cards = all()
            let card: Card
            if let index = cards.firstIndex(where: {
                $0.headword == headword && $0.reading == reading
            }) {
                cards[index].sightings.append(sighting)
                card = cards[index]
            } else {
                card = Card(
                    headword: headword, reading: reading, entryID: entryID, sightings: [sighting],
                    created: sighting.date)
                cards.append(card)
            }
            try save(cards)
            return card
        }
    }

    public func remove(_ card: Card) throws {
        try queue.sync {
            try save(all().filter { $0.id != card.id })
        }
    }

    public func update(_ card: Card) throws {
        try queue.sync {
            var cards = all()
            guard let index = cards.firstIndex(where: { $0.id == card.id }) else { return }
            cards[index] = card
            try save(cards)
        }
    }

    private func all() -> [Card] {
        if let loaded { return loaded }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let cards =
            (try? Data(contentsOf: url)).flatMap { try? decoder.decode([Card].self, from: $0) }
            ?? []
        loaded = cards
        return cards
    }

    private func save(_ cards: [Card]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(cards).write(to: url, options: .atomic)
        loaded = cards
    }
}
