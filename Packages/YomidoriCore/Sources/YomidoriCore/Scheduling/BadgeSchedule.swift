import Foundation

/// The app icon's count of questions due, as it will stand while the app is closed: each time
/// a question comes due the count goes up by one, and nothing answers it until the app is
/// open again.
public enum BadgeSchedule {
    /// The moments after `now` a question comes due, grouped into the hour they fall in and
    /// stepped at that hour's end, so the icon never counts a question before it is due; the
    /// count at each step, from `base`, the count due now; the first `limit` steps.
    public static func steps(
        dueDates: [Date], after now: Date, base: Int, limit: Int = 60,
        calendar: Calendar = .current
    ) -> [(date: Date, count: Int)] {
        var byHour: [Date: Int] = [:]
        for date in dueDates where date > now {
            let hour = calendar.dateInterval(of: .hour, for: date)?.end ?? date
            byHour[hour, default: 0] += 1
        }
        var count = base
        return byHour.keys.sorted().prefix(limit).map { hour in
            count += byHour[hour] ?? 0
            return (hour, count)
        }
    }
}

extension Card {
    /// When the card's questions come due after `now`, while it is in review: the ones due
    /// already count now, not later; the pitch only where it is asked.
    public func upcomingDue(after now: Date, asksPitch: Bool) -> [Date] {
        guard isInReview else { return [] }
        return Question.allCases.compactMap { question in
            guard question != .pitch || asksPitch,
                let due = state(for: question)?.due, due > now
            else { return nil }
            return due
        }
    }
}
