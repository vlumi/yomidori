import Foundation

/// Everything the reader has made, as one file to keep: the cards, the collections and the
/// lookup history. The covers are pictures and stay out; sync carries those. Restoring adds
/// what the file has to what is there, merged as sync merges, and takes nothing away.
public struct Backup: Equatable, Sendable {
    public var created: Date
    public var cards: [Card]
    public var collections: [Collection]
    public var lookups: [Lookup]

    public static let version = 1
    /// Far above any reader's cards, far below what would choke the phone.
    public static let largestFile = 50_000_000

    public init(
        created: Date, cards: [Card], collections: [Collection] = [], lookups: [Lookup] = []
    ) {
        self.created = created
        self.cards = cards
        self.collections = collections
        self.lookups = lookups
    }

    /// The file's name, by the day where the reader is: the ISO style alone counts the day
    /// in Greenwich, which in Tokyo is yesterday until nine in the morning.
    public static func fileName(at date: Date, timeZone: TimeZone = .current) -> String {
        let day = date.formatted(
            Date.ISO8601FormatStyle(timeZone: timeZone).year().month().day())
        return "Yomidori backup \(day)"
    }

    private struct File: Encodable {
        let version: Int
        let created: Date
        let cards: [Card]
        let collections: [Collection]
        let lookups: [Lookup]
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(
            File(
                version: Self.version, created: created, cards: cards,
                collections: collections, lookups: lookups))
    }

    /// A backup, or the cards file alone as earlier builds shared it. Each record is cleaned
    /// as any record coming in; one that cannot be read is left out, not the file refused.
    public static func decoded(from data: Data) throws -> Backup {
        guard data.count <= largestFile else { throw CocoaError(.fileReadTooLarge) }
        let json = try JSONSerialization.jsonObject(with: data)
        if let cards = json as? [Any] {
            return Backup(created: .distantPast, cards: records(Card.self, in: cards))
        }
        guard let file = json as? [String: Any], file["cards"] is [Any] else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let created = (file["created"] as? String).flatMap {
            ISO8601DateFormatter().date(from: $0)
        }
        return Backup(
            created: created ?? .distantPast,
            cards: records(Card.self, in: file["cards"]),
            collections: records(Collection.self, in: file["collections"]),
            lookups: records(Lookup.self, in: file["lookups"]))
    }

    private static func records<Record: Decodable & Sanitizable>(
        _ type: Record.Type, in list: Any?
    ) -> [Record] {
        ((list as? [Any]) ?? []).compactMap { element in
            (try? JSONSerialization.data(withJSONObject: element)).flatMap {
                SyncPayload.intake(type, from: $0)
            }
        }
    }
}

extension Backup {
    /// What a restore comes to: the stores' new contents, and how much of it was new.
    public struct Restored: Equatable, Sendable {
        public var cards: [Card]
        public var collections: [Collection]
        public var lookups: [Lookup]
        public var addedCards = 0
        public var joinedCards = 0
        public var addedCollections = 0
    }

    /// The backup laid onto what is there. A card is its word's, whatever id the file gave
    /// it, and joins the word's card where there is one; a collection joins its own by id; a
    /// lookup older than the last clear of the history stays gone.
    public func restored(
        onto cards: [Card], collections: [Collection], lookups: [Lookup], clearedAt: Date?,
        lookupLimit: Int
    ) -> Restored {
        var result = Restored(cards: cards, collections: collections, lookups: lookups)
        (result.addedCards, result.joinedCards) = lay(cardsOnto: &result.cards)
        result.addedCollections = lay(collectionsOnto: &result.collections)
        lay(lookupsOnto: &result.lookups, clearedAt: clearedAt, limit: lookupLimit)
        return result
    }

    /// The backup restored into the stores themselves. Each store is merged inside its own
    /// write, onto what it holds at that moment, so a change that lands meanwhile, a sync's,
    /// is kept; laid onto contents read beforehand, it would be written over and its
    /// records sent on as deleted.
    public func restore(
        cards: FileCardStore, collections: FileCollectionStore, lookups: FileLookupHistory
    ) throws -> Restored {
        var result = Restored(cards: [], collections: [], lookups: [])
        // The collections first, so no card points at one that is not there yet.
        try collections.replaceAll { held in
            var held = held
            result.addedCollections = lay(collectionsOnto: &held)
            result.collections = held
            return held
        }
        try cards.replaceAll { held in
            var held = held
            (result.addedCards, result.joinedCards) = lay(cardsOnto: &held)
            result.cards = held
            return held
        }
        let clearedAt = lookups.clearedAt
        try lookups.replaceAll { held in
            var held = held
            lay(lookupsOnto: &held, clearedAt: clearedAt, limit: FileLookupHistory.limit)
            result.lookups = held
            return held
        }
        return result
    }

    /// How many cards were new, and how many gained something.
    private func lay(cardsOnto held: inout [Card]) -> (added: Int, joined: Int) {
        var added = 0
        var joined = 0
        var place = Dictionary(
            held.enumerated().map { ($0.element.id, $0.offset) },
            uniquingKeysWith: { first, _ in first })
        for card in cards.map(\.keyedByWord) {
            if let index = place[card.id] {
                let merged = held[index].merged(with: card)
                if merged != held[index] { joined += 1 }
                held[index] = merged
            } else {
                place[card.id] = held.count
                held.append(card)
                added += 1
            }
        }
        return (added, joined)
    }

    /// How many collections were new.
    private func lay(collectionsOnto held: inout [Collection]) -> Int {
        var added = 0
        for collection in collections {
            if let index = held.firstIndex(where: { $0.id == collection.id }) {
                held[index] = held[index].merged(with: collection)
            } else {
                held.append(collection)
                added += 1
            }
        }
        return added
    }

    private func lay(lookupsOnto held: inout [Lookup], clearedAt: Date?, limit: Int) {
        let cutoff = clearedAt ?? .distantPast
        var byWord = Dictionary(held.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for lookup in lookups where lookup.date > cutoff {
            byWord[lookup.id] = byWord[lookup.id].map { $0.merged(with: lookup) } ?? lookup
        }
        held = Array(byWord.values.sorted { $0.date > $1.date }.prefix(limit))
    }
}

extension Card {
    /// The card under its word's own id, as every card has been since ids were made from
    /// the word; a backup from before may carry another.
    var keyedByWord: Card {
        let id = WordKey.cardID(headword: headword, reading: reading)
        guard id != self.id else { return self }
        return Card(
            id: id, headword: headword, reading: reading, entryID: entryID, sightings: sightings,
            created: created, modified: modified, review: review, meaningReview: meaningReview,
            pitchReview: pitchReview, log: log, acceptedMeanings: acceptedMeanings,
            started: started, shelved: shelved, collectionIDs: collectionIDs)
    }
}
