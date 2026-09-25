import Foundation

/// One day's reviewing, folded from the cards' logs: how many answers to each question, how
/// many right (a "count it right" is right), the seconds spent, and the words started.
public struct DayTally: Equatable, Sendable {
    /// The day's start in the calendar the tallies were made with.
    public let day: Date
    public var answered: [Question: Int] = [:]
    public var right: [Question: Int] = [:]
    public var seconds = 0
    public var started = 0

    public init(day: Date) {
        self.day = day
    }

    public var total: Int { answered.values.reduce(0, +) }
    public var rightTotal: Int { right.values.reduce(0, +) }

    /// Nil for a day with nothing answered.
    public var accuracy: Double? {
        total == 0 ? nil : Double(rightTotal) / Double(total)
    }

    public func accuracy(of question: Question) -> Double? {
        let asked = answered[question] ?? 0
        return asked == 0 ? nil : Double(right[question] ?? 0) / Double(asked)
    }
}

/// What the logs say about the reviewing done, by day.
public enum Progress {
    /// A tally for every day from `from`'s to `to`'s, the quiet days included, oldest first.
    public static func tallies(
        of cards: [Card], from: Date, to: Date, calendar: Calendar = .current
    ) -> [DayTally] {
        let first = calendar.startOfDay(for: from)
        let last = calendar.startOfDay(for: to)
        guard first <= last else { return [] }
        var byDay: [Date: DayTally] = [:]
        var day = first
        while day <= last {
            byDay[day] = DayTally(day: day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        for card in cards {
            for entry in card.log {
                let day = calendar.startOfDay(for: entry.date)
                guard byDay[day] != nil else { continue }
                byDay[day]?.answered[entry.question, default: 0] += 1
                if entry.grade == .good { byDay[day]?.right[entry.question, default: 0] += 1 }
                byDay[day]?.seconds += entry.seconds
            }
            if let started = card.started {
                let day = calendar.startOfDay(for: started)
                byDay[day]?.started += 1
            }
        }
        return byDay.values.sorted { $0.day < $1.day }
    }

    /// The days in a row with an answer, counted back from `date`'s day; a day not yet
    /// reviewed on doesn't break the run until it is over.
    public static func streak(of cards: [Card], at date: Date, calendar: Calendar = .current)
        -> Int
    {
        let days = Set(cards.flatMap(\.log).map { calendar.startOfDay(for: $0.date) })
        var day = calendar.startOfDay(for: date)
        if !days.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else {
                return 0
            }
            day = yesterday
        }
        var run = 0
        while days.contains(day), let before = calendar.date(byAdding: .day, value: -1, to: day) {
            run += 1
            day = before
        }
        return run
    }

    /// Everything ever answered.
    public struct Total: Equatable, Sendable {
        public var answered = 0
        public var right = 0
        public var seconds = 0

        public init(answered: Int = 0, right: Int = 0, seconds: Int = 0) {
            self.answered = answered
            self.right = right
            self.seconds = seconds
        }

        public var accuracy: Double? {
            answered == 0 ? nil : Double(right) / Double(answered)
        }
    }

    public static func total(of cards: [Card]) -> Total {
        cards.flatMap(\.log).reduce(into: Total()) { sum, entry in
            sum.answered += 1
            if entry.grade == .good { sum.right += 1 }
            sum.seconds += entry.seconds
        }
    }
}
