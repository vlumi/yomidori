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
    public var meaningReview: ReviewState?
    public var pitchReview: ReviewState?

    public init(
        id: UUID = UUID(), headword: String, reading: String, entryID: Int?,
        sightings: [Sighting], created: Date, review: ReviewState? = nil,
        meaningReview: ReviewState? = nil, pitchReview: ReviewState? = nil
    ) {
        self.id = id
        self.headword = headword
        self.reading = reading
        self.entryID = entryID
        self.sightings = sightings
        self.created = created
        self.review = review
        self.meaningReview = meaningReview
        self.pitchReview = pitchReview
    }

    public func isDue(at date: Date) -> Bool {
        review.map { $0.due <= date } ?? true
    }

    /// The reading and the meaning are always asked; the pitch only when it is known.
    public func dueQuestions(at date: Date, asksPitch: Bool) -> [Question] {
        Question.allCases.filter { question in
            (question != .pitch || asksPitch)
                && (state(for: question).map { $0.due <= date } ?? true)
        }
    }

    public func state(for question: Question) -> ReviewState? {
        switch question {
        case .reading: return review
        case .meaning: return meaningReview
        case .pitch: return pitchReview
        }
    }

    public mutating func setState(_ state: ReviewState, for question: Question) {
        switch question {
        case .reading: review = state
        case .meaning: meaningReview = state
        case .pitch: pitchReview = state
        }
    }

    public mutating func replace(_ sighting: Sighting) {
        guard let index = sightings.firstIndex(where: { $0.id == sighting.id }) else { return }
        sightings[index] = sighting
    }

    // The first cards were written with the reading's state only.
    private enum CodingKeys: String, CodingKey {
        case id, headword, reading, entryID, sightings, created, review, meaningReview, pitchReview
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
        meaningReview = try c.decodeIfPresent(ReviewState.self, forKey: .meaningReview)
        pitchReview = try c.decodeIfPresent(ReviewState.self, forKey: .pitchReview)
    }
}

public enum Question: String, Codable, Sendable, Hashable, CaseIterable {
    case reading
    case meaning
    case pitch
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

    /// The sighting with its sentence rewritten; the word is found again in the new text,
    /// at the old place when it is still there, else at its first occurrence, else nowhere.
    public func withSentence(_ text: String) -> Sighting {
        let sentence = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let unchanged = Sighting(
            id: id, sentence: sentence, surface: surface, offset: offset, stillIDs: stillIDs,
            cropID: cropID, source: source, date: date)
        if let range = unchanged.surfaceRange, sentence[range] == surface { return unchanged }
        let offset = sentence.range(of: surface).map {
            sentence.distance(from: sentence.startIndex, to: $0.lowerBound)
        }
        return Sighting(
            id: id, sentence: sentence, surface: surface, offset: offset ?? -1, stillIDs: stillIDs,
            cropID: cropID, source: source, date: date)
    }

    public func withoutImages() -> Sighting {
        Sighting(
            id: id, sentence: sentence, surface: surface, offset: offset, stillIDs: [], cropID: nil,
            source: source, date: date)
    }

    public var hasImages: Bool {
        !stillIDs.isEmpty || cropID != nil
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
