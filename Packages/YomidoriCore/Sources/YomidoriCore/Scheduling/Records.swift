import Foundation

/// Days in a row with an answer, a lesson's practice counted like any review: a day with
/// nothing due is a gap unless something new was started and practised.
public struct Streak: Equatable, Sendable {
    /// The first and last days' starts.
    public let first: Date
    public let last: Date
    public let days: Int

    public init(first: Date, last: Date, days: Int) {
        self.first = first
        self.last = last
        self.days = days
    }

    /// Still open at `date`: its last day is that day or the one before, so today's
    /// reviewing can lengthen it.
    public func isOngoing(at date: Date, calendar: Calendar = .current) -> Bool {
        let today = calendar.startOfDay(for: date)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
            return last == today
        }
        return last == today || last == yesterday
    }
}

/// A high mark and the day, or the week's start, it was set.
public struct Record: Equatable, Sendable {
    public let value: Int
    public let day: Date

    public init(value: Int, day: Date) {
        self.value = value
        self.day = day
    }
}

public enum Records {
    /// The days with an answer, each at its start.
    public static func studiedDays(of cards: [Card], calendar: Calendar = .current) -> Set<Date> {
        Set(cards.flatMap(\.log).map { calendar.startOfDay(for: $0.date) })
    }

    /// Every run of studied days, longest first and the latest first among equals, so the
    /// top of the list is the record and an open run can be found by its last day.
    public static func streaks(of cards: [Card], calendar: Calendar = .current) -> [Streak] {
        streaks(over: studiedDays(of: cards, calendar: calendar), calendar: calendar)
    }

    public static func streaks(over days: Set<Date>, calendar: Calendar = .current) -> [Streak] {
        var runs: [Streak] = []
        var first: Date?
        var last: Date?
        var count = 0
        for day in days.sorted() {
            if let end = last, calendar.date(byAdding: .day, value: 1, to: end) == day {
                count += 1
            } else {
                if let first, let last {
                    runs.append(Streak(first: first, last: last, days: count))
                }
                first = day
                count = 1
            }
            last = day
        }
        if let first, let last { runs.append(Streak(first: first, last: last, days: count)) }
        return runs.sorted { $0.days != $1.days ? $0.days > $1.days : $0.first > $1.first }
    }

    /// The highest of one number over the periods, the first period to reach it: a record
    /// is set once and then equalled. Nil where no period has any.
    public static func most(_ number: KeyPath<DayTally, Int>, in periods: [DayTally]) -> Record? {
        var best: Record?
        for period in periods {
            let value = period[keyPath: number]
            if value > 0, value > (best?.value ?? 0) {
                best = Record(value: value, day: period.day)
            }
        }
        return best
    }
}
