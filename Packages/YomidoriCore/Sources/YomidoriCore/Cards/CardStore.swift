import Foundation

public protocol CardStore {
    func cards() -> [Card]
    func card(headword: String, reading: String) -> Card?
    /// Adds the sighting to the word's card, making the card if there is none, and puts the
    /// card into `collection` when one is given.
    @discardableResult
    func keep(
        _ sighting: Sighting, headword: String, reading: String, entryID: Int?, collection: UUID?
    ) throws -> Card
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

    var recency: Date {
        card.state(for: question)?.lastReview ?? card.started ?? card.created
    }
}

extension CardStore {
    @discardableResult
    public func keep(_ sighting: Sighting, headword: String, reading: String, entryID: Int?)
        throws -> Card
    {
        try keep(sighting, headword: headword, reading: reading, entryID: entryID, collection: nil)
    }

    /// Takes the collection off every card in it, as when the collection is deleted.
    public func forget(collection: UUID) throws {
        for var card in cards() where card.collectionIDs.contains(collection) {
            card.remove(from: collection)
            try update(card)
        }
    }

    public func waiting() -> [Card] {
        cards().filter(\.isWaiting)
    }

    /// The longest overdue first, then the oldest.
    public func due(at date: Date) -> [Card] {
        cards().filter { $0.isDue(at: date) }
            .sorted { ($0.review?.due ?? $0.created) < ($1.review?.due ?? $1.created) }
    }

    /// A card contributes an item per due question, the reading before the meaning before
    /// the pitch; `asksPitch` says which cards have a pitch to ask. The most recently
    /// answered come first, a just-started card counting from its start, so a short session
    /// churns the fresh cards and the backlog trails.
    public func dueItems(at date: Date, asksPitch: (Card) -> Bool = { _ in false }) -> [ReviewItem]
    {
        cards().flatMap { card in
            card.dueQuestions(at: date, asksPitch: asksPitch(card)).map {
                ReviewItem(card: card, question: $0)
            }
        }
        .sorted { first, second in
            let (a, b) = (first.recency, second.recency)
            return a == b ? first.question.rawValue < second.question.rawValue : a > b
        }
    }
}

/// One JSON document, written whole and atomically on every change.
public final class FileCardStore: CardStore {
    public let url: URL
    private var loaded: [Card]?
    private let queue = DispatchQueue(label: "fi.misaki.yomidori.cards")
    /// Called after every write, outside the store's lock, so a listener may read back.
    public var didChange: (() -> Void)?

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

    public func keep(
        _ sighting: Sighting, headword: String, reading: String, entryID: Int?, collection: UUID?
    ) throws -> Card {
        let kept = try queue.sync { () -> Card in
            var cards = all()
            let index: Int
            if let found = cards.firstIndex(where: {
                $0.headword == headword && $0.reading == reading
            }) {
                cards[found].add(sighting)
                index = found
            } else {
                cards.append(
                    Card(
                        headword: headword, reading: reading, entryID: entryID,
                        sightings: [sighting], created: sighting.date))
                index = cards.count - 1
            }
            if let collection { cards[index].add(to: collection) }
            try save(cards)
            return cards[index]
        }
        didChange?()
        return kept
    }

    public func remove(_ card: Card) throws {
        try queue.sync {
            try save(all().filter { $0.id != card.id })
        }
        didChange?()
    }

    public func update(_ card: Card) throws {
        try queue.sync {
            var cards = all()
            guard let index = cards.firstIndex(where: { $0.id == card.id }) else { return }
            cards[index] = card
            try save(cards)
        }
        didChange?()
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
