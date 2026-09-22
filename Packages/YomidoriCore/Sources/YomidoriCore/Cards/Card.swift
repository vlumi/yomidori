import Foundation

/// One word kept, keyed by dictionary form and reading; meeting it again adds a sighting.
public struct Card: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let headword: String
    public let reading: String
    public let entryID: Int?
    public var sightings: [Sighting]
    public let created: Date
    /// When the card's content last changed: a sighting added, a sentence corrected, photos
    /// dropped. Reviews do not move it; they have their own dates.
    public private(set) var modified: Date
    public var review: ReviewState?
    public var meaningReview: ReviewState?
    public var pitchReview: ReviewState?
    /// Every answer given, in order.
    public private(set) var log: [ReviewEntry]
    /// Meanings the reader accepts beside the dictionary's glosses.
    public var acceptedMeanings: [String]
    /// When a lesson put the card into review; nil while it waits.
    public private(set) var started: Date?
    /// Kept for the record and never reviewed: a name, a place.
    public private(set) var shelved: Bool
    /// The collections the card is in, a book each usually; none is fine.
    public var collectionIDs: [UUID]

    public init(
        id: UUID = UUID(), headword: String, reading: String, entryID: Int?,
        sightings: [Sighting], created: Date, modified: Date? = nil, review: ReviewState? = nil,
        meaningReview: ReviewState? = nil, pitchReview: ReviewState? = nil,
        log: [ReviewEntry] = [], acceptedMeanings: [String] = [], started: Date? = nil,
        shelved: Bool = false, collectionIDs: [UUID] = []
    ) {
        self.id = id
        self.headword = headword
        self.reading = reading
        self.entryID = entryID
        self.sightings = sightings
        self.created = created
        self.modified = modified ?? created
        self.review = review
        self.meaningReview = meaningReview
        self.pitchReview = pitchReview
        self.log = log
        self.acceptedMeanings = acceptedMeanings
        self.started = started
        self.shelved = shelved
        self.collectionIDs = collectionIDs
    }

    public mutating func add(to collection: UUID) {
        if !collectionIDs.contains(collection) { collectionIDs.append(collection) }
    }

    public mutating func remove(from collection: UUID) {
        collectionIDs.removeAll { $0 == collection }
    }

    public var isWaiting: Bool { started == nil && !shelved }
    public var isInReview: Bool { started != nil && !shelved }

    /// The reading and the meaning are always asked; the pitch only when it is known.
    /// `asksPitch` is asked only when the pitch question is due, since it costs a lookup.
    public func dueQuestions(at date: Date, asksPitch: @autoclosure () -> Bool) -> [Question] {
        guard isInReview else { return [] }
        return Question.allCases.filter { question in
            (state(for: question).map { $0.due <= date } ?? true)
                && (question != .pitch || asksPitch())
        }
    }

    public mutating func start(at date: Date) {
        started = date
        shelved = false
    }

    /// Back to the waiting stack with no schedule; the log stays.
    public mutating func sendToWaiting() {
        started = nil
        shelved = false
        review = nil
        meaningReview = nil
        pitchReview = nil
    }

    public mutating func shelve() {
        sendToWaiting()
        shelved = true
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

    public mutating func replace(_ sighting: Sighting, at date: Date = Date()) {
        guard let index = sightings.firstIndex(where: { $0.id == sighting.id }) else { return }
        sightings[index] = sighting
        modified = date
    }

    public mutating func add(_ sighting: Sighting) {
        sightings.append(sighting)
        modified = max(modified, sighting.date)
    }

    /// The scheduler's verdict and a line in the log; `reconciled` when the reader overruled
    /// a wrong verdict.
    public mutating func answer(
        _ question: Question, grade: Grade, at date: Date, reconciled: Bool = false
    ) {
        setState(FSRS.review(state(for: question), grade: grade, at: date), for: question)
        log.append(
            ReviewEntry(date: date, question: question, grade: grade, reconciled: reconciled))
    }

    public func answers(to question: Question, graded grade: Grade) -> Int {
        log.filter { $0.question == question && $0.grade == grade }.count
    }

    // A missing `modified` reads as the latest sighting, a missing log as empty, and a card
    // with no `started` is in review if it was ever reviewed, else it waits.
    private enum CodingKeys: String, CodingKey {
        case id, headword, reading, entryID, sightings, created, modified, review, meaningReview
        case pitchReview, log, acceptedMeanings, started, shelved, collectionIDs
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        headword = try c.decode(String.self, forKey: .headword)
        reading = try c.decode(String.self, forKey: .reading)
        entryID = try c.decodeIfPresent(Int.self, forKey: .entryID)
        sightings = try c.decode([Sighting].self, forKey: .sightings)
        created = try c.decode(Date.self, forKey: .created)
        modified =
            try c.decodeIfPresent(Date.self, forKey: .modified)
            ?? sightings.map(\.date).max() ?? created
        review = try c.decodeIfPresent(ReviewState.self, forKey: .review)
        meaningReview = try c.decodeIfPresent(ReviewState.self, forKey: .meaningReview)
        pitchReview = try c.decodeIfPresent(ReviewState.self, forKey: .pitchReview)
        log = try c.decodeIfPresent([ReviewEntry].self, forKey: .log) ?? []
        acceptedMeanings = try c.decodeIfPresent([String].self, forKey: .acceptedMeanings) ?? []
        shelved = try c.decodeIfPresent(Bool.self, forKey: .shelved) ?? false
        collectionIDs = try c.decodeIfPresent([UUID].self, forKey: .collectionIDs) ?? []
        if c.contains(.started) {
            started = try c.decodeIfPresent(Date.self, forKey: .started)
        } else {
            started = [review, meaningReview, pitchReview].compactMap { $0?.lastReview }.min()
        }
    }
}

public struct ReviewEntry: Hashable, Codable, Sendable {
    public let date: Date
    public let question: Question
    public let grade: Grade
    public let reconciled: Bool

    public init(date: Date, question: Question, grade: Grade, reconciled: Bool) {
        self.date = date
        self.question = question
        self.grade = grade
        self.reconciled = reconciled
    }
}

public enum Question: Int, Codable, Sendable, Hashable, CaseIterable {
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
        // Earlier shapes of `stillIDs`, still read: one still, or a still and its continuation.
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
