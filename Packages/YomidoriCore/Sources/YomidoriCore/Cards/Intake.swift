import Foundation

/// What a record from outside the app (a shared collection, another device through sync) may
/// hold: every string cleaned and cut, every list bounded, every number sane, so a hostile or
/// broken file can neither break a screen nor fill the phone.
public enum Intake {
    public static let wordLength = 100
    public static let readingLength = 200
    public static let sentenceLength = 2_000
    public static let nameLength = 200
    public static let noteLength = 2_000
    public static let tagLength = 60
    public static let tags = 50
    public static let sightings = 500
    public static let answers = 20_000
    public static let meanings = 100
    public static let collectionsPerCard = 500
}

extension Intake {
    /// No record of this app is older than its first build, and none comes from later than
    /// tomorrow: a date outside that is a clock gone wrong or a hostile file, and is drawn
    /// to the nearer edge rather than left to run the progress charts back to year one.
    public static let earliest = Date(timeIntervalSince1970: 1_704_067_200)  // 2024-01-01

    public static func date(_ date: Date, now: Date = Date()) -> Date {
        min(max(date, earliest), now.addingTimeInterval(86_400))
    }

    /// Stability is in days; a hundred years is more than any schedule asks.
    public static let longestStability: Double = 36_500
}

extension Sighting {
    public func sanitized() -> Sighting {
        let sentence = Sanitize.text(sentence, limit: Intake.sentenceLength)
        let surface = Sanitize.text(surface, limit: Intake.wordLength)
        // Written so that an offset near Int.max cannot overflow the sum.
        let fits = offset >= 0 && offset <= sentence.count - surface.count
        return Sighting(
            id: id, sentence: sentence, surface: surface, offset: fits ? offset : -1,
            source: source.map { Sanitize.text($0, limit: Intake.nameLength) },
            date: Intake.date(date))
    }
}

extension ReviewState {
    /// Nil for a state the scheduler could not work with: a stability that is zero, negative
    /// or not a number would make every later interval nonsense.
    public func sanitized() -> ReviewState? {
        guard stability.isFinite, stability > 0, difficulty.isFinite else { return nil }
        let lastReview = Intake.date(lastReview)
        return ReviewState(
            stability: min(stability, Intake.longestStability),
            difficulty: min(max(difficulty, 1), 10),
            // Due no later than the stability says, from the last review.
            due: min(
                max(due, Intake.earliest),
                lastReview.addingTimeInterval(Intake.longestStability * 86_400)),
            lastReview: lastReview, reviews: max(reviews, 0), lapses: max(lapses, 0))
    }
}

/// A record that can be cleaned on its way in; nil when nothing usable is left.
public protocol Sanitizable {
    func sanitized() -> Self?
}

extension Card: Sanitizable {
    /// Nil when the word itself is missing.
    public func sanitized() -> Card? {
        let headword = Sanitize.text(headword, limit: Intake.wordLength)
        let reading = Sanitize.text(reading, limit: Intake.readingLength)
        guard !headword.isEmpty, !reading.isEmpty else { return nil }
        return Card(
            id: id, headword: headword, reading: reading, entryID: entryID,
            sightings: sightings.prefix(Intake.sightings).map { $0.sanitized() },
            created: Intake.date(created), modified: Intake.date(modified),
            review: review?.sanitized(),
            meaningReview: meaningReview?.sanitized(), pitchReview: pitchReview?.sanitized(),
            log: log.suffix(Intake.answers).map { entry in
                ReviewEntry(
                    date: Intake.date(entry.date), question: entry.question, grade: entry.grade,
                    reconciled: entry.reconciled, seconds: entry.seconds)
            },
            acceptedMeanings: Sanitize.texts(
                acceptedMeanings, count: Intake.meanings, limit: Intake.nameLength),
            started: started.map { Intake.date($0) }, shelved: shelved,
            collectionIDs: Array(collectionIDs.prefix(Intake.collectionsPerCard)))
    }
}

extension Collection: Sanitizable {
    public func sanitized() -> Collection? {
        let name = Sanitize.text(name, limit: Intake.nameLength)
        guard !name.isEmpty else { return nil }
        return Collection(
            id: id, name: name, created: created,
            note: Sanitize.text(note, limit: Intake.noteLength),
            tags: Sanitize.texts(tags, count: Intake.tags, limit: Intake.tagLength),
            coverID: coverID,
            modified: modified)
    }
}

extension Lookup: Sanitizable {
    public func sanitized() -> Lookup? {
        let headword = Sanitize.text(headword, limit: Intake.wordLength)
        let reading = Sanitize.text(reading, limit: Intake.readingLength)
        guard !headword.isEmpty else { return nil }
        return Lookup(
            headword: headword, reading: reading, entryID: entryID, date: date, source: source)
    }
}

extension SyncPayload {
    /// CloudKit's own ceiling for a record.
    public static let largest = 1_000_000

    /// A record from another device, decoded only when of a sane size and then cleaned.
    public static func intake<Record: Decodable & Sanitizable>(_ type: Record.Type, from data: Data)
        -> Record?
    {
        guard data.count <= largest else { return nil }
        return (try? decode(type, from: data))?.sanitized()
    }

    /// A clear of the history from another device; one dated past tomorrow is a clock gone
    /// wrong, and would empty the history for good, so it is not taken.
    public static func clearDate(_ date: Date?, now: Date = Date()) -> Date? {
        guard let date, date <= now.addingTimeInterval(86_400) else { return nil }
        return date
    }
}
