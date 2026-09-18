import Foundation

/// One word the reader asked about, kept. A card is the word in its dictionary
/// form with its reading, never one sighting: meeting the word again in another
/// book adds a sighting to the same card. The reading and pitch are looked up
/// live from the dictionary; the sightings are the reader's own.
public struct Card: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    /// The dictionary form, as JMdict lists it: the card's key together with the reading.
    public let headword: String
    /// The reading in hiragana.
    public let reading: String
    /// The JMdict entry, when the word was found in it.
    public let entryID: Int?
    public var sightings: [Sighting]
    public let created: Date
    /// The scheduler's memory of the card; nil until the first review, and due at once then.
    public var review: ReviewState?

    public init(
        id: UUID = UUID(), headword: String, reading: String, entryID: Int?,
        sightings: [Sighting], created: Date, review: ReviewState? = nil
    ) {
        self.id = id
        self.headword = headword
        self.reading = reading
        self.entryID = entryID
        self.sightings = sightings
        self.created = created
        self.review = review
    }

    /// Whether the card is due at `date`: never reviewed, or its due date has come.
    public func isDue(at date: Date) -> Bool {
        review.map { $0.due <= date } ?? true
    }
}

/// The word as it was met once: the sentence as it stood on the page, where in it
/// the word sits and how it was spelled there, the still it came from, and when.
public struct Sighting: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let sentence: String
    /// The word's form on the page (頷いた, not 頷く) and where it starts in `sentence`,
    /// in characters, so the front can highlight it without re-tokenizing.
    public let surface: String
    public let offset: Int
    /// The still the sentence was read from, kept as an image file by this id.
    public let stillID: UUID?
    /// Where it was read, in the reader's words: a book, a page. Optional.
    public let source: String?
    public let date: Date

    public init(
        id: UUID = UUID(), sentence: String, surface: String, offset: Int, stillID: UUID?,
        source: String?, date: Date
    ) {
        self.id = id
        self.sentence = sentence
        self.surface = surface
        self.offset = offset
        self.stillID = stillID
        self.source = source
        self.date = date
    }
}
