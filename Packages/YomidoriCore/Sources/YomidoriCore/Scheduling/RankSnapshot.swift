import Foundation

/// How many cards stood at each rank at the start of a day, so the day's own reviewing
/// shows on the next; replayed from the cards by `RankHistory`.
public struct RankSnapshot: Codable, Equatable, Sendable {
    /// The day's start.
    public let day: Date
    /// By `Rank.index`: the nest first, then the egg and the climb.
    public let counts: [Int]
    /// The same for each question, by its raw value; nil in a snapshot that does not count
    /// them apart.
    public let byQuestion: [Int: [Int]]?

    public init(day: Date, counts: [Int], byQuestion: [Int: [Int]]? = nil) {
        self.day = day
        self.counts = counts
        self.byQuestion = byQuestion
    }

    public static func of(_ cards: [Card], day: Date) -> RankSnapshot {
        var counts = Array(repeating: 0, count: Rank.allCases.count)
        var byQuestion: [Int: [Int]] = [:]
        for question in Question.allCases {
            byQuestion[question.rawValue] = Array(repeating: 0, count: Rank.allCases.count)
        }
        for card in cards {
            counts[card.rank.index] += 1
            // A kana word's reading is not asked, so it has no rank to count.
            for question in Question.allCases where question != .reading || card.asksReading {
                byQuestion[question.rawValue]?[card.rank(for: question).index] += 1
            }
        }
        return RankSnapshot(day: day, counts: counts, byQuestion: byQuestion)
    }

    public func count(of rank: Rank) -> Int {
        counts.indices.contains(rank.index) ? counts[rank.index] : 0
    }

    /// The count for one question; nil where the snapshot has none for it.
    public func count(of rank: Rank, for question: Question) -> Int? {
        guard let counts = byQuestion?[question.rawValue], counts.indices.contains(rank.index)
        else { return nil }
        return counts[rank.index]
    }

    /// Whether the snapshot counts the questions apart.
    public var hasQuestions: Bool { byQuestion != nil }

    public var total: Int { counts.reduce(0, +) }

    /// One snapshot a period, the first of each, for a chart over months; `.day` keeps all.
    public static func thinned(
        _ snapshots: [RankSnapshot], by component: Calendar.Component,
        calendar: Calendar = .current
    ) -> [RankSnapshot] {
        guard component != .day else { return snapshots }
        var seen: Set<Date> = []
        return snapshots.sorted { $0.day < $1.day }.filter { snapshot in
            let start =
                calendar.dateInterval(of: component, for: snapshot.day)?.start ?? snapshot.day
            return seen.insert(start).inserted
        }
    }
}
