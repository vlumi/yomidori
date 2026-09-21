import Foundation

/// One word kept, keyed by dictionary form and reading; meeting it again adds a sighting.
public struct Card: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let headword: String
    public let reading: String
    public let entryID: Int?
    public var sightings: [Sighting]
    public let created: Date
    public var review: ReviewState?
    public var asksMeaning: Bool
    public var meaningReview: ReviewState?

    public init(
        id: UUID = UUID(), headword: String, reading: String, entryID: Int?,
        sightings: [Sighting], created: Date, review: ReviewState? = nil, asksMeaning: Bool = false,
        meaningReview: ReviewState? = nil
    ) {
        self.id = id
        self.headword = headword
        self.reading = reading
        self.entryID = entryID
        self.sightings = sightings
        self.created = created
        self.review = review
        self.asksMeaning = asksMeaning
        self.meaningReview = meaningReview
    }

    public func isDue(at date: Date) -> Bool {
        review.map { $0.due <= date } ?? true
    }

    public func dueQuestions(at date: Date) -> [Question] {
        var questions: [Question] = []
        if isDue(at: date) { questions.append(.reading) }
        if asksMeaning, meaningReview.map({ $0.due <= date }) ?? true { questions.append(.meaning) }
        return questions
    }

    public func state(for question: Question) -> ReviewState? {
        question == .reading ? review : meaningReview
    }

    public mutating func setState(_ state: ReviewState, for question: Question) {
        if question == .reading { review = state } else { meaningReview = state }
    }

    // The first cards were written without the meaning fields; they read as off.
    private enum CodingKeys: String, CodingKey {
        case id, headword, reading, entryID, sightings, created, review, asksMeaning, meaningReview
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        headword = try c.decode(String.self, forKey: .headword)
        reading = try c.decode(String.self, forKey: .reading)
        entryID = try c.decodeIfPresent(Int.self, forKey: .entryID)
        sightings = try c.decode([Sighting].self, forKey: .sightings)
        created = try c.decode(Date.self, forKey: .created)
        review = try c.decodeIfPresent(ReviewState.self, forKey: .review)
        asksMeaning = try c.decodeIfPresent(Bool.self, forKey: .asksMeaning) ?? false
        meaningReview = try c.decodeIfPresent(ReviewState.self, forKey: .meaningReview)
    }
}

public enum Question: String, Codable, Sendable, Hashable {
    case reading
    case meaning
}

public struct Sighting: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let sentence: String
    /// The word's form on the page and where it starts in `sentence`, in characters.
    public let surface: String
    public let offset: Int
    public let stillIDs: [UUID]
    public let cropID: UUID?
    public let source: String?
    public let date: Date

    /// Nil when the sentence has been edited out from under the offset.
    public var surfaceRange: Range<String.Index>? {
        guard offset >= 0, offset + surface.count <= sentence.count else { return nil }
        let start = sentence.index(sentence.startIndex, offsetBy: offset)
        return start..<sentence.index(start, offsetBy: surface.count)
    }

    public init(
        id: UUID = UUID(), sentence: String, surface: String, offset: Int, stillIDs: [UUID],
        cropID: UUID? = nil, source: String?, date: Date
    ) {
        self.id = id
        self.sentence = sentence
        self.surface = surface
        self.offset = offset
        self.stillIDs = stillIDs
        self.cropID = cropID
        self.source = source
        self.date = date
    }

    private enum CodingKeys: String, CodingKey {
        case id, sentence, surface, offset, stillIDs, cropID, source, date
        // The one-still shape of the first cards, and the two-still one after it.
        case stillID, continuationStillID
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        sentence = try c.decode(String.self, forKey: .sentence)
        surface = try c.decode(String.self, forKey: .surface)
        offset = try c.decode(Int.self, forKey: .offset)
        source = try c.decodeIfPresent(String.self, forKey: .source)
        cropID = try c.decodeIfPresent(UUID.self, forKey: .cropID)
        date = try c.decode(Date.self, forKey: .date)
        if let ids = try c.decodeIfPresent([UUID].self, forKey: .stillIDs) {
            stillIDs = ids
        } else {
            stillIDs = [
                try c.decodeIfPresent(UUID.self, forKey: .stillID),
                try c.decodeIfPresent(UUID.self, forKey: .continuationStillID),
            ].compactMap { $0 }
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(sentence, forKey: .sentence)
        try c.encode(surface, forKey: .surface)
        try c.encode(offset, forKey: .offset)
        try c.encode(stillIDs, forKey: .stillIDs)
        try c.encodeIfPresent(cropID, forKey: .cropID)
        try c.encodeIfPresent(source, forKey: .source)
        try c.encode(date, forKey: .date)
    }
}
