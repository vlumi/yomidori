import Charts
import SwiftUI
import YomidoriCore

/// The reviewing done: today and all time in numbers, and over a chosen span the answers
/// right and wrong, the ranks as they stood, and the words started. A finger on a chart
/// shows that period's numbers above it.
struct ProgressScreen: View {
    /// How far back the charts look, and how finely: days for a month, weeks for a season,
    /// months for longer.
    enum Span: String, CaseIterable, Identifiable {
        case fourWeeks
        case threeMonths
        case year
        case all

        var id: String { rawValue }

        var days: Int? {
            switch self {
            case .fourWeeks: return 28
            case .threeMonths: return 91
            case .year: return 365
            case .all: return nil
            }
        }

        var unit: Calendar.Component {
            switch self {
            case .fourWeeks: return .day
            case .threeMonths: return .weekOfYear
            case .year, .all: return .month
            }
        }

        var title: Text {
            switch self {
            case .fourWeeks: return Text("4 weeks", bundle: .module)
            case .threeMonths: return Text("3 months", bundle: .module)
            case .year: return Text("Year", bundle: .module)
            case .all: return Text("All", bundle: .module)
            }
        }
    }

    @State private var span: Span = .fourWeeks
    @State private var question: Question?
    @State private var today: DayTally?
    @State private var buckets: [DayTally] = []
    @State private var snapshots: [RankSnapshot] = []
    @State private var streak = 0
    @State private var total = Progress.Total()
    @State private var started = 0

    var body: some View {
        List {
            if total.answered == 0 && snapshots.count < 2 {
                Text("Nothing reviewed yet. Do a lesson, then a review.", bundle: .module)
                    .foregroundStyle(.secondary)
            } else {
                stats
                Section {
                    Picker(selection: $span) {
                        ForEach(Span.allCases) { span in span.title.tag(span) }
                    } label: {
                        Text("Span", bundle: .module)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                Section {
                    Picker(selection: $question) {
                        Text("All", bundle: .module).tag(Question?.none)
                        ForEach(Question.allCases, id: \.self) { question in
                            Text(verbatim: question.name).tag(Question?.some(question))
                        }
                    } label: {
                        Text("Question", bundle: .module)
                    }
                    .pickerStyle(.segmented)
                    AnswersChart(buckets: buckets, unit: span.unit, question: question)
                } header: {
                    Text("Reviews", bundle: .module)
                }
                if snapshots.count >= 2 {
                    Section {
                        RankHistoryChart(snapshots: snapshots, unit: span.unit)
                    } header: {
                        Text("Ranks", bundle: .module)
                    }
                }
                Section {
                    StartedChart(buckets: buckets, unit: span.unit)
                } header: {
                    Text("Words started", bundle: .module)
                }
            }
        }
        .navigationTitle(Text("Progress", bundle: .module))
        .onAppear(perform: reload)
        .onChange(of: span) { reload() }
        .onReceive(Cards.changes(of: [.card])) { _ in reload() }
    }

    private var stats: some View {
        Group {
            Section {
                StatRow(stats: [
                    Stat(value: "\(today?.total ?? 0)", label: Text("Reviews", bundle: .module)),
                    Stat(
                        value: Percent.text(today?.accuracy), label: Text("Right", bundle: .module)),
                    Stat(
                        value: "\((today?.seconds ?? 0) / 60)",
                        label: Text("Minutes", bundle: .module)),
                    Stat(value: "\(streak)", label: Text("Days in a row", bundle: .module)),
                ])
            } header: {
                Text("Today", bundle: .module)
            }
            Section {
                StatRow(stats: [
                    Stat(value: "\(total.answered)", label: Text("Reviews", bundle: .module)),
                    Stat(
                        value: Percent.text(total.accuracy), label: Text("Right", bundle: .module)),
                    Stat(value: Self.hours(total.seconds), label: Text("Hours", bundle: .module)),
                    Stat(value: "\(started)", label: Text("Words started", bundle: .module)),
                ])
            } header: {
                Text("All time", bundle: .module)
            }
        }
    }

    private func reload() {
        let cards = Cards.store?.cards() ?? []
        let calendar = Calendar.current
        let now = Date()
        today = Progress.tallies(of: cards, from: now, to: now, calendar: calendar).first
        streak = Progress.streak(of: cards, at: now, calendar: calendar)
        total = Progress.total(of: cards)
        started = cards.filter { $0.started != nil }.count
        let all = Cards.snapshots?.snapshots() ?? []
        let from: Date
        if let days = span.days {
            from = calendar.date(byAdding: .day, value: 1 - days, to: now) ?? now
        } else {
            from = [Progress.earliest(of: cards), all.first?.day].compactMap { $0 }.min() ?? now
        }
        // Whole periods: a week's bucket holds the whole week, not from the span's first day.
        let start = calendar.dateInterval(of: span.unit, for: from)?.start ?? from
        buckets = Progress.rollUp(
            Progress.tallies(of: cards, from: start, to: now, calendar: calendar),
            by: span.unit, calendar: calendar)
        snapshots = RankSnapshot.thinned(
            all.filter { $0.day >= start }, by: span.unit, calendar: calendar)
    }

    private static func hours(_ seconds: Int) -> String {
        let hours = Double(seconds) / 3600
        return hours < 10 ? String(format: "%.1f", hours) : "\(Int(hours.rounded()))"
    }
}

private enum Percent {
    static func text(_ fraction: Double?) -> String {
        fraction.map { "\(Int(($0 * 100).rounded()))%" } ?? "–"
    }
}

/// A period's name: the day, the week's first and last day, or the month.
private enum Period {
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

    /// The period a finger on the chart is over: the last one starting at or before it.
    static func under<Element>(_ date: Date?, in periods: [Element], start: (Element) -> Date)
        -> Element?
    {
        guard let date else { return nil }
        return periods.last { start($0) <= date }
    }
}

private struct Stat {
    let value: String
    let label: Text
}

/// Four numbers side by side, each over its name.
private struct StatRow: View {
    let stats: [Stat]

    var body: some View {
        HStack(alignment: .top) {
            ForEach(Array(stats.enumerated()), id: \.offset) { _, stat in
                VStack(spacing: 2) {
                    Text(verbatim: stat.value)
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()
                    stat.label
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.vertical, 4)
    }
}

/// The line above a chart: the period under the finger, or the whole span.
private struct ChartCaption<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 8) { content() }
            .font(.callout)
            .frame(minHeight: 30)
            .accessibilityElement(children: .combine)
    }
}

extension Question {
    /// The question's name, for a picker or a legend.
    var name: String {
        switch self {
        case .reading: return String(localized: "Reading", bundle: .module)
        case .meaning: return String(localized: "Meaning", bundle: .module)
        case .pitch: return String(localized: "Pitch", bundle: .module)
        }
    }

    /// Green for the reading, the sky's blue for the meaning, amber for the pitch.
    var color: Color {
        switch self {
        case .reading: return Palette.nightGreen
        case .meaning: return Rank.flying.color
        case .pitch: return Color(red: 0.85, green: 0.58, blue: 0.20)
        }
    }
}

/// Answers a period as a bar, the right ones in color and the wrong on top in gray, for one
/// question or all; the caption says how many and the share right.
private struct AnswersChart: View {
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
        let picked = Period.under(selected, in: buckets, start: \.day)
        let shownAnswered = picked.map(answered) ?? buckets.map(answered).reduce(0, +)
        let shownRight = picked.map(right) ?? buckets.map(right).reduce(0, +)
        let rightName = String(localized: "Right", bundle: .module)
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
private struct RankHistoryChart: View {
    let snapshots: [RankSnapshot]
    let unit: Calendar.Component
    @State private var selected: Date?

    var body: some View {
        let shown = Period.under(selected, in: snapshots, start: \.day) ?? snapshots.last
        VStack(alignment: .leading, spacing: 8) {
            ChartCaption {
                if let shown {
                    Text(verbatim: Period.label(shown.day, unit: .day)).fontWeight(.semibold)
                    Text("\(shown.total) cards", bundle: .module)
                    Spacer()
                    ForEach(Rank.allCases.filter { shown.count(of: $0) > 0 }, id: \.self) { rank in
                        HStack(spacing: 2) {
                            RankMark(rank: rank, size: 18)
                            Text(verbatim: "\(shown.count(of: rank))").font(.caption)
                        }
                    }
                }
            }
            Chart {
                ForEach(snapshots, id: \.day) { snapshot in
                    ForEach(Rank.allCases, id: \.self) { rank in
                        AreaMark(
                            x: .value(String(localized: "Day", bundle: .module), snapshot.day),
                            y: .value(
                                String(localized: "Cards", bundle: .module),
                                snapshot.count(of: rank))
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
private struct StartedChart: View {
    let buckets: [DayTally]
    let unit: Calendar.Component
    @State private var selected: Date?

    var body: some View {
        let picked = Period.under(selected, in: buckets, start: \.day)
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
