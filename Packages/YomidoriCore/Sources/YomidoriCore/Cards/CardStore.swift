import Foundation

public protocol CardStore {
    func cards() -> [Card]
    func card(headword: String, reading: String) -> Card?
    @discardableResult
    func keep(_ sighting: Sighting, headword: String, reading: String, entryID: Int?) throws -> Card
    func remove(_ card: Card) throws
    func update(_ card: Card) throws
}

public struct ReviewItem: Hashable, Sendable {
    public let card: Card
    public let question: Question

    public init(card: Card, question: Question) {
        self.card = card
        self.question = question
    }
}

extension CardStore {
    /// The longest overdue first, then the oldest.
    public func due(at date: Date) -> [Card] {
        cards().filter { $0.isDue(at: date) }
            .sorted { ($0.review?.due ?? $0.created) < ($1.review?.due ?? $1.created) }
    }

    /// A card contributes an item per due question, the reading before the meaning before
    /// the pitch; `asksPitch` says which cards have a pitch to ask.
    public func dueItems(at date: Date, asksPitch: (Card) -> Bool = { _ in false }) -> [ReviewItem]
    {
        cards().flatMap { card in
            card.dueQuestions(at: date, asksPitch: asksPitch(card)).map {
                ReviewItem(card: card, question: $0)
            }
        }
        .sorted {
            ($0.card.state(for: $0.question)?.due ?? $0.card.created)
                < ($1.card.state(for: $1.question)?.due ?? $1.card.created)
        }
    }
}

/// One JSON document, written whole and atomically on every change.
public final class FileCardStore: CardStore {
    private let url: URL
    private var loaded: [Card]?
    private let queue = DispatchQueue(label: "fi.misaki.yomidori.cards")

    public init(url: URL) {
        self.url = url
    }

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
