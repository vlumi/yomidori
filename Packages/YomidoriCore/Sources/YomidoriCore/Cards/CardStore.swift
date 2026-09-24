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

    public func card(id: UUID) -> Card? {
        cards().first { $0.id == id }
    }

    /// Answers on the card as the store holds it now, not as the item took it: the items of
    /// one card share the card, and each answer changes it.
    @discardableResult
    public func answer(
        _ item: ReviewItem, grade: Grade, at date: Date, reconciled: Bool = false,
        accepting meaning: String? = nil
    ) throws -> Card {
        var card = self.card(id: item.card.id) ?? item.card
        if let meaning, !card.acceptedMeanings.contains(meaning) {
            card.acceptedMeanings.append(meaning)
        }
        card.answer(item.question, grade: grade, at: date, reconciled: reconciled)
        try update(card)
        return card
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
    public let file: RecordFile<Card>
    public var url: URL { file.url }

    public init(url: URL) {
        file = RecordFile(url: url, label: "fi.misaki.yomidori.cards") { $0.id.uuidString }
    }

    public func cards() -> [Card] {
        file.records()
    }

    public func card(headword: String, reading: String) -> Card? {
        cards().first { $0.headword == headword && $0.reading == reading }
    }

    public func keep(
        _ sighting: Sighting, headword: String, reading: String, entryID: Int?, collection: UUID?
    ) throws -> Card {
        try file.write { cards in
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
            return cards[index]
        }
    }

    public func remove(_ card: Card) throws {
        try file.write { $0.removeAll { $0.id == card.id } }
    }

    public func update(_ card: Card) throws {
        try file.write { cards in
            guard let index = cards.firstIndex(where: { $0.id == card.id }) else { return }
            cards[index] = card
        }
    }

    // TEMPORARY: remove once the cards kept before ids were made from the word are re-keyed
    // (one device, at the launch after this ships), with its test and its call in `Cards`.
    /// Every card under its word's own id; cards of one word are merged into one. The old
    /// ids go out to sync as deletes, the new as saves.
    public func keyCardsByWord() throws {
        try file.write { cards in
            guard cards.contains(where: { $0.id != $0.wordID }) else { return }
            var order: [UUID] = []
            var byWord: [UUID: Card] = [:]
            for card in cards.sorted(by: { $0.created < $1.created }) {
                let rekeyed = card.withID(card.wordID)
                if let earlier = byWord[card.wordID] {
                    byWord[card.wordID] = earlier.merged(with: rekeyed)
                } else {
                    order.append(card.wordID)
                    byWord[card.wordID] = rekeyed
                }
            }
            cards = order.compactMap { byWord[$0] }
        }
    }

    /// Many changes in one write, as an import makes them.
    public func replaceAll(_ transform: ([Card]) -> [Card]) throws {
        try file.write { $0 = transform($0) }
    }

    public func applyRemote(saving saved: [Card], deleting deleted: Set<UUID>) throws {
        try file.write(.remote) {
            $0.apply(saving: saved, deleting: Set(deleted.map(\.uuidString)), key: \.id.uuidString)
        }
    }
}

// TEMPORARY: goes with `keyCardsByWord`.
extension Card {
    fileprivate var wordID: UUID { WordKey.cardID(headword: headword, reading: reading) }

    fileprivate func withID(_ id: UUID) -> Card {
        Card(
            id: id, headword: headword, reading: reading, entryID: entryID, sightings: sightings,
            created: created, modified: modified, review: review, meaningReview: meaningReview,
            pitchReview: pitchReview, log: log, acceptedMeanings: acceptedMeanings,
            started: started, shelved: shelved, collectionIDs: collectionIDs)
    }
}
