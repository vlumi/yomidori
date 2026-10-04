import Foundation

/// The questions coming due, by quarter day and by the rank of their cards, for a look
/// ahead: how much now, how much each morning, afternoon, evening and night after, and
/// whether a wall is on its way.
public struct Upcoming: Equatable, Sendable {
    /// A day in four: night, morning, afternoon, evening.
    public static let slotsPerDay = 4

    /// A quarter of a day and the questions that come due in it, by the rank of their card.
    public struct Slot: Equatable, Sendable, Identifiable {
        public let start: Date
        public let end: Date
        public var counts: [Rank: Int]

        public init(start: Date, end: Date, counts: [Rank: Int] = [:]) {
            self.start = start
            self.end = end
            self.counts = counts
        }

        public var id: Date { start }
        public var questions: Int { counts.values.reduce(0, +) }

        public func contains(_ date: Date) -> Bool { start <= date && date < end }

        /// The ranks that come up in the slot, each with where its part of the bar lies.
        public var shares: [Share] {
            var stacked = 0
            return Rank.allCases.compactMap { rank in
                guard let count = counts[rank], count > 0 else { return nil }
                defer { stacked += count }
                return Share(rank: rank, from: stacked, to: stacked + count)
            }
        }
    }

    /// A rank's part of a slot's bar, stacked from the lowest rank up.
    public struct Share: Equatable, Sendable {
        public let rank: Rank
        public let from: Int
        public let to: Int
    }

    /// A day's total, for the words beside the picture.
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

    /// Today's quarters first, from the day's start; what was due before now counts in the
    /// quarter now is in.
    public var slots: [Slot]
    /// The same by day, today first.
    public var days: [Day]
    /// What comes due after the days counted.
    public var later: Int

    public init(slots: [Slot] = [], days: [Day] = [], later: Int = 0) {
        self.slots = slots
        self.days = days
        self.later = later
    }

    /// The most on any one day, for a bar to be drawn against.
    public var most: Int { days.map(\.questions).max() ?? 0 }

    /// Every question in the days counted, by rank.
    public var counts: [Rank: Int] {
        slots.reduce(into: [:]) { total, slot in
            total.merge(slot.counts, uniquingKeysWith: +)
        }
    }

    public var questions: Int { counts.values.reduce(0, +) }

    /// Nothing comes due, in the days counted or after.
    public var isEmpty: Bool { questions < 1 && later < 1 }

    /// Every question of the cards in review, placed in the quarter day it comes due: one
    /// never answered is due now, one overdue counts as now's. `asksPitch` says which cards
    /// have a pitch to ask, as the review's own queue is told.
    public static func of(
        _ cards: [Card], from now: Date, days: Int, calendar: Calendar = .current,
        asksPitch: (Card) -> Bool = { _ in false }
    ) -> Upcoming {
        let today = calendar.startOfDay(for: now)
        let starts = (0..<max(days, 0)).map { offset in
            calendar.date(byAdding: .day, value: offset, to: today) ?? today
        }
        var slots: [Slot] = starts.flatMap { day -> [Slot] in
            let next = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            let hours = 24 / slotsPerDay
            return (0..<slotsPerDay).map { quarter in
                Slot(
                    start: calendar.date(byAdding: .hour, value: quarter * hours, to: day) ?? day,
                    end: quarter + 1 < slotsPerDay
                        ? calendar.date(byAdding: .hour, value: (quarter + 1) * hours, to: day)
                            ?? next
                        : next)
            }
        }
        var later = 0
        for card in cards where card.isInReview {
            let rank = card.rank
            for question in Question.allCases where question != .pitch || asksPitch(card) {
                let due = max(card.state(for: question)?.due ?? now, now)
                if let index = slots.firstIndex(where: { $0.contains(due) }) {
                    slots[index].counts[rank, default: 0] += 1
                } else {
                    later += 1
                }
            }
        }
        let byDay = starts.map { day in
            Day(
                day: day,
                questions: slots.filter { calendar.startOfDay(for: $0.start) == day }
                    .map(\.questions).reduce(0, +))
        }
        return Upcoming(slots: slots, days: byDay, later: later)
    }
}
