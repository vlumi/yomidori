import Foundation

/// One answer given: when, to which question, how it was graded, whether the reader overruled
/// the verdict, how long it took, and the zone it was given in.
public struct ReviewEntry: Hashable, Codable, Sendable {
    public let date: Date
    public let question: Question
    public let grade: Grade
    public let reconciled: Bool
    /// From the question shown to the answer graded, at most `longestCounted`: a phone put
    /// down mid-question doesn't count as an hour's study.
    public let seconds: Int
    /// The zone the answer was given in, as seconds east of Greenwich at that moment, so
    /// the day it counts for is the day it was given on, wherever the reader is later; nil
    /// for an answer logged before zones were kept.
    public let zoneOffset: Int?

    public static let longestCounted = 60

    public init(
        date: Date, question: Question, grade: Grade, reconciled: Bool, seconds: Int = 0,
        zone: TimeZone? = .current
    ) {
        self.init(
            date: date, question: question, grade: grade, reconciled: reconciled,
            seconds: seconds, zoneOffset: zone?.secondsFromGMT(for: date))
    }

    public init(
        date: Date, question: Question, grade: Grade, reconciled: Bool, seconds: Int,
        zoneOffset: Int?
    ) {
        self.date = date
        self.question = question
        self.grade = grade
        self.reconciled = reconciled
        self.seconds = min(max(seconds, 0), Self.longestCounted)
        self.zoneOffset = zoneOffset
    }

    private enum CodingKeys: String, CodingKey {
        case date, question, grade, reconciled, seconds
        case zoneOffset = "zone"
    }

    /// An entry written before the time was kept reads as 0 seconds, one before zones were
    /// kept as no zone, neither as unreadable.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            date: try c.decode(Date.self, forKey: .date),
            question: try c.decode(Question.self, forKey: .question),
            grade: try c.decode(Grade.self, forKey: .grade),
            reconciled: try c.decode(Bool.self, forKey: .reconciled),
            seconds: try c.decodeIfPresent(Int.self, forKey: .seconds) ?? 0,
            zoneOffset: try c.decodeIfPresent(Int.self, forKey: .zoneOffset))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(date, forKey: .date)
        try c.encode(question, forKey: .question)
        try c.encode(grade, forKey: .grade)
        try c.encode(reconciled, forKey: .reconciled)
        try c.encode(seconds, forKey: .seconds)
        try c.encodeIfPresent(zoneOffset, forKey: .zoneOffset)
    }

    /// The start, in `calendar`, of the day the answer was given on where it was given: an
    /// answer at 23:30 in Tokyo stays on that date seen from Helsinki. An entry with no
    /// zone takes the viewer's day.
    public func day(in calendar: Calendar) -> Date {
        guard let zoneOffset, let zone = TimeZone(secondsFromGMT: zoneOffset) else {
            return calendar.startOfDay(for: date)
        }
        var there = calendar
        there.timeZone = zone
        let parts = there.dateComponents([.year, .month, .day], from: date)
        return calendar.date(from: parts).map(calendar.startOfDay(for:))
            ?? calendar.startOfDay(for: date)
    }

    /// The same answer, whether or not its zone was kept: how two devices' logs are matched.
    var answer: Answer {
        Answer(
            date: date, question: question, grade: grade, reconciled: reconciled, seconds: seconds)
    }

    struct Answer: Hashable {
        let date: Date
        let question: Question
        let grade: Grade
        let reconciled: Bool
        let seconds: Int
    }
}

public enum Question: Int, Codable, Sendable, Hashable, CaseIterable {
    case reading
    case meaning
    case pitch
}
