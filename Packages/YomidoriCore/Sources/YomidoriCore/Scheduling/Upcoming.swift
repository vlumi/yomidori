import Foundation

/// The questions coming due, by day, for a look ahead: how much today, how much each day
/// after, and whether a wall is on its way.
public struct Upcoming: Equatable, Sendable {
    public struct Day: Equatable, Sendable, Identifiable {
        /// The day's start in the calendar the count was made with.
        public let day: Date
        /// The questions that come due that day.
        public var questions: Int

        public init(day: Date, questions: Int) {
            self.day = day
            self.questions = questions
        }

        public var id: Date { day }
    }

    /// Today first, with whatever was due before it and is still unanswered.
    public var days: [Day]
    /// What comes due after the days counted.
    public var later: Int

    public init(days: [Day] = [], later: Int = 0) {
        self.days = days
        self.later = later
    }

    /// The most on any one day, for a bar to be drawn against.
    public var most: Int { days.map(\.questions).max() ?? 0 }

    /// Nothing comes due, in the days counted or after.
    public var isEmpty: Bool { most < 1 && later < 1 }

    /// Every question of the cards in review, placed on the day it comes due: one never
    /// answered is due now, one overdue counts as today's. `asksPitch` says which cards have
    /// a pitch to ask, as the review's own queue is told.
    public static func of(
        _ cards: [Card], from now: Date, days: Int, calendar: Calendar = .current,
        asksPitch: (Card) -> Bool = { _ in false }
    ) -> Upcoming {
        let today = calendar.startOfDay(for: now)
        var counts = Array(repeating: 0, count: max(days, 0))
        var later = 0
        for card in cards where card.isInReview {
            for question in Question.allCases where question != .pitch || asksPitch(card) {
                let due = card.state(for: question)?.due ?? now
                let ahead =
                    calendar.dateComponents(
                        [.day], from: today, to: calendar.startOfDay(for: due)
                    ).day ?? 0
                let index = max(ahead, 0)
                if index < counts.count { counts[index] += 1 } else { later += 1 }
            }
        }
        return Upcoming(
            days: counts.enumerated().map { offset, count in
                Day(
                    day: calendar.date(byAdding: .day, value: offset, to: today) ?? today,
                    questions: count)
            }, later: later)
    }
}
