import Foundation

/// A collection as it is handed to someone else: its name, note and tags, and its words with
/// the sentences they were met in. No photos, no cover and no reviews: the receiver starts the
/// words fresh, and the file stays small.
public struct SharedCollection: Codable, Equatable, Sendable {
    public static let format = "yomidori-collection"

    public struct Word: Codable, Equatable, Sendable {
        public let headword: String
        public let reading: String
        public let entryID: Int?
        public let sentences: [Sentence]
    }

    public struct Sentence: Codable, Equatable, Sendable {
        public let sentence: String
        public let surface: String
        public let offset: Int
        public let source: String?
    }

    public struct DecodeError: Error {}

    public let format: String
    public let version: Int
    public let name: String
    public let note: String
    public let tags: [String]
    public let words: [Word]

    public init(collection: Collection, cards: [Card]) {
        format = Self.format
        version = 1
        name = collection.name
        note = collection.note
        tags = collection.tags
        words = cards.filter { $0.collectionIDs.contains(collection.id) }.map { card in
            Word(
                headword: card.headword, reading: card.reading, entryID: card.entryID,
                sentences: card.sightings.map {
                    Sentence(
                        sentence: $0.sentence, surface: $0.surface, offset: $0.offset,
                        source: $0.source)
                })
        }
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// A shared collection is words and sentences; five megabytes is thousands of them.
    public static let largestFile = 5_000_000
    public static let mostWords = 20_000

    /// Only a file in this format, of a sane size, and cleaned: every string cut and freed of
    /// control characters, every list bounded, words without a headword or reading dropped.
    public static func decoded(from data: Data) throws -> SharedCollection {
        guard data.count <= largestFile else { throw DecodeError() }
        let shared = try JSONDecoder().decode(SharedCollection.self, from: data)
        guard shared.format == format, shared.version == 1 else { throw DecodeError() }
        let name = Sanitize.text(shared.name, limit: Intake.nameLength)
        guard !name.isEmpty else { throw DecodeError() }
        return SharedCollection(
            name: name, note: Sanitize.text(shared.note, limit: Intake.noteLength),
            tags: Sanitize.texts(shared.tags, count: Intake.tags, limit: Intake.tagLength),
            words: shared.words.prefix(mostWords).compactMap { $0.sanitized() })
    }

    private init(name: String, note: String, tags: [String], words: [Word]) {
        format = Self.format
        version = 1
        self.name = name
        self.note = note
        self.tags = tags
        self.words = words
    }

    public struct Merged: Equatable, Sendable {
        public let cards: [Card]
        public let added: Int
        public let joined: Int
    }

    /// The words into `cards` and `collection`: a word already on a card joins the collection
    /// and gains the sentences it lacks; a new word becomes a waiting card, kept `date`.
    public func merge(into cards: [Card], collection: UUID, at date: Date) -> Merged {
        var cards = cards
        var added = 0
        var joined = 0
        for word in words {
            let sightings = word.sentences.map {
                Sighting(
                    sentence: $0.sentence, surface: $0.surface, offset: $0.offset,
                    source: $0.source, date: date)
            }
            if let index = cards.firstIndex(where: {
                $0.headword == word.headword && $0.reading == word.reading
            }) {
                let known = Set(cards[index].sightings.map(\.sentence))
                for sighting in sightings
                where !sighting.sentence.isEmpty
                    && !known.contains(sighting.sentence)
                {
                    cards[index].add(sighting)
                }
                cards[index].add(to: collection)
                joined += 1
            } else {
                var card = Card(
                    headword: word.headword, reading: word.reading, entryID: word.entryID,
                    sightings: sightings, created: date)
                card.add(to: collection)
                cards.append(card)
                added += 1
            }
        }
        return Merged(cards: cards, added: added, joined: joined)
    }
}

extension SharedCollection.Word {
    func sanitized() -> SharedCollection.Word? {
        let headword = Sanitize.text(headword, limit: Intake.wordLength)
        let reading = Sanitize.text(reading, limit: Intake.readingLength)
        guard !headword.isEmpty, !reading.isEmpty else { return nil }
        return SharedCollection.Word(
            headword: headword, reading: reading, entryID: entryID,
            sentences: sentences.prefix(Intake.sightings).map { sentence in
                let clean = Sighting(
                    sentence: sentence.sentence, surface: sentence.surface, offset: sentence.offset,
                    source: sentence.source, date: Date()
                ).sanitized()
                return SharedCollection.Sentence(
                    sentence: clean.sentence, surface: clean.surface, offset: clean.offset,
                    source: clean.source)
            })
    }
}
