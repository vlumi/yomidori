import Foundation

/// How far back the progress charts look, and how finely: days for a month, weeks for a
/// season, months for longer or for everything.
public enum ProgressSpan: String, CaseIterable, Identifiable, Sendable {
    case fourWeeks
    case threeMonths
    case year
    case all

    public var id: String { rawValue }

    /// The days the span covers, counting today; nil for everything there is.
    public var days: Int? {
        switch self {
        case .fourWeeks: return 28
        case .threeMonths: return 91
        case .year: return 365
        case .all: return nil
        }
    }

    /// What one bucket of the chart holds.
    public var unit: Calendar.Component {
        switch self {
        case .fourWeeks: return .day
        case .threeMonths: return .weekOfYear
        case .year, .all: return .month
        }
    }

    /// Where the span starts: the first day covered, or the earliest there is, taken back
    /// to the start of its period, so a week's bucket holds the whole week and not from
    /// the span's first day.
    public func start(now: Date, earliest: Date?, calendar: Calendar = .current) -> Date {
        let from: Date
        if let days {
            from = calendar.date(byAdding: .day, value: 1 - days, to: now) ?? now
        } else {
            from = earliest ?? now
        }
        return calendar.dateInterval(of: unit, for: from)?.start ?? from
    }

    /// The period a finger on the chart is over: the last one starting at or before it.
    public static func period<Element>(
        under date: Date?, in periods: [Element], start: (Element) -> Date
    ) -> Element? {
        guard let date else { return nil }
        return periods.last { start($0) <= date }
    }
}
