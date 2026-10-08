import Charts
import SwiftUI
import YomidoriCore

/// A period's name: the day, the week's first and last day, or the month.
enum Period {
    static func label(_ start: Date, unit: Calendar.Component, calendar: Calendar = .current)
        -> String
    {
        switch unit {
        case .day:
            return start.formatted(.dateTime.month(.abbreviated).day())
        case .weekOfYear:
            let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
            return start.formatted(.dateTime.month(.abbreviated).day()) + " – "
                + end.formatted(.dateTime.month(.abbreviated).day())
        default:
            return start.formatted(.dateTime.year().month(.wide))
        }
    }

}

/// The line above a chart: the period under the finger, or the whole span.
struct ChartCaption<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 8) { content() }
            .font(.callout)
            .frame(minHeight: 30)
            .accessibilityElement(children: .combine)
    }
}

/// Answers a period as a bar, the right ones in color and the wrong on top in gray, for one
/// question or all; the caption says how many and the share right.
struct AnswersChart: View {
    let buckets: [DayTally]
    let unit: Calendar.Component
    let question: Question?
    @State private var selected: Date?

    private func answered(_ bucket: DayTally) -> Int {
        question.map { bucket.answered[$0] ?? 0 } ?? bucket.total
    }

    private func right(_ bucket: DayTally) -> Int {
        question.map { bucket.right[$0] ?? 0 } ?? bucket.rightTotal
    }

    var body: some View {
        let picked = ProgressSpan.period(under: selected, in: buckets, start: \.day)
        let shownAnswered = picked.map(answered) ?? buckets.map(answered).reduce(0, +)
        let shownRight = picked.map(right) ?? buckets.map(right).reduce(0, +)
        let rightName = String(localized: "Correct", bundle: .module)
        let wrongName = String(localized: "Wrong", bundle: .module)
        VStack(alignment: .leading, spacing: 8) {
            ChartCaption {
                if let picked {
                    Text(verbatim: Period.label(picked.day, unit: unit)).fontWeight(.semibold)
                }
                Text("\(shownAnswered) answers · \(shownRight) right", bundle: .module)
                if shownAnswered > 0 {
                    Text(verbatim: Percent.text(Double(shownRight) / Double(shownAnswered)))
                        .fontWeight(.semibold)
                }
            }
            Chart {
                ForEach(buckets, id: \.day) { bucket in
                    BarMark(
                        x: .value(
                            String(localized: "Day", bundle: .module), bucket.day, unit: unit),
                        y: .value(rightName, right(bucket))
                    )
                    .foregroundStyle(
                        by: .value(String(localized: "Result", bundle: .module), rightName))
                    BarMark(
                        x: .value(
                            String(localized: "Day", bundle: .module), bucket.day, unit: unit),
                        y: .value(wrongName, answered(bucket) - right(bucket))
                    )
                    .foregroundStyle(
                        by: .value(String(localized: "Result", bundle: .module), wrongName))
                }
                if let picked {
                    RuleMark(
                        x: .value(String(localized: "Day", bundle: .module), picked.day, unit: unit)
                    )
                    .foregroundStyle(.secondary.opacity(0.5))
                }
            }
            .chartForegroundStyleScale([
                rightName: question?.color ?? Palette.nightGreen, wrongName: Color(white: 0.72),
            ])
            .chartXSelection(value: $selected)
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) }
            .frame(height: 160)
        }
    }
}

/// The cards at each rank as the periods went, stacked from the nest up; the caption gives
/// the counts of the snapshot under the finger, or the latest.
struct RankHistoryChart: View {
    let snapshots: [RankSnapshot]
    let unit: Calendar.Component
    /// One question's ranks, from the snapshots that count them apart; nil for the cards'.
    var question: Question?
    @State private var selected: Date?

    private var counted: [RankSnapshot] {
        question == nil ? snapshots : snapshots.filter(\.hasQuestions)
    }

    private func count(_ snapshot: RankSnapshot, _ rank: Rank) -> Int {
        question.flatMap { snapshot.count(of: rank, for: $0) } ?? snapshot.count(of: rank)
    }

    var body: some View {
        let snapshots = counted
        let shown =
            ProgressSpan.period(under: selected, in: snapshots, start: \.day) ?? snapshots.last
        VStack(alignment: .leading, spacing: 8) {
            // The day and its total, and the ranks' numbers: on one line where they fit, on
            // two where seven ranks and a phone's width would wrap every word.
            if let shown {
                FitsOrStacks(spacing: 8, trailingLast: true) {
                    HStack(spacing: 8) {
                        Text(verbatim: Period.label(shown.day, unit: .day)).fontWeight(.semibold)
                        Text("\(shown.total) cards", bundle: .module)
                    }
                    .fixedSize()
                    HStack(spacing: 6) {
                        ForEach(Rank.allCases.filter { count(shown, $0) > 0 }, id: \.self) { rank in
                            HStack(spacing: 2) {
                                RankMark(rank: rank, size: 18)
                                Text(verbatim: "\(count(shown, rank))").font(.subheadline)
                            }
                        }
                    }
                    .fixedSize()
                }
                .font(.callout)
                .frame(minHeight: 30)
                .accessibilityElement(children: .combine)
            }
            Chart {
                ForEach(snapshots, id: \.day) { snapshot in
                    ForEach(Rank.allCases, id: \.self) { rank in
                        AreaMark(
                            x: .value(String(localized: "Day", bundle: .module), snapshot.day),
                            y: .value(
                                String(localized: "Cards", bundle: .module),
                                count(snapshot, rank))
                        )
                        .foregroundStyle(
                            by: .value(
                                String(localized: "Rank", bundle: .module), "\(rank.rawValue)"))
                    }
                }
                if let shown, selected != nil {
                    RuleMark(x: .value(String(localized: "Day", bundle: .module), shown.day))
                        .foregroundStyle(.secondary.opacity(0.5))
                }
            }
            .chartForegroundStyleScale(
                domain: Rank.allCases.map { "\($0.rawValue)" }, range: Rank.allCases.map(\.color)
            )
            .chartLegend(.hidden)
            .chartXSelection(value: $selected)
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) }
            .frame(height: 180)
        }
    }
}

/// The words a lesson started each period.
struct StartedChart: View {
    let buckets: [DayTally]
    let unit: Calendar.Component
    @State private var selected: Date?

    var body: some View {
        let picked = ProgressSpan.period(under: selected, in: buckets, start: \.day)
        let shown = picked?.started ?? buckets.map(\.started).reduce(0, +)
        VStack(alignment: .leading, spacing: 8) {
            ChartCaption {
                if let picked {
                    Text(verbatim: Period.label(picked.day, unit: unit)).fontWeight(.semibold)
                }
                Text("\(shown) words started", bundle: .module)
            }
            Chart {
                ForEach(buckets, id: \.day) { bucket in
                    BarMark(
                        x: .value(
                            String(localized: "Day", bundle: .module), bucket.day, unit: unit),
                        y: .value(
                            String(localized: "Words started", bundle: .module), bucket.started)
                    )
                    .foregroundStyle(Rank.hatchling.color)
                }
                if let picked {
                    RuleMark(
                        x: .value(String(localized: "Day", bundle: .module), picked.day, unit: unit)
                    )
                    .foregroundStyle(.secondary.opacity(0.5))
                }
            }
            .chartXSelection(value: $selected)
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) }
            .frame(height: 120)
        }
    }
}
