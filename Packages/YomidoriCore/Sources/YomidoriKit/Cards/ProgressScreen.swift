import Charts
import SwiftUI
import YomidoriCore

/// The reviewing done, by day: today and the run of days, the answers by question and how
/// many were right, the ranks as they stood each morning, and the words started.
struct ProgressScreen: View {
    @State private var days: [DayTally] = []
    @State private var snapshots: [RankSnapshot] = []
    @State private var streak = 0
    @State private var total = Progress.Total()
    @State private var started = 0

    static let daysShown = 28
    static let snapshotsShown = 90

    var body: some View {
        List {
            if total.answered == 0 && snapshots.count < 2 {
                Text("Nothing reviewed yet. Do a lesson, then a review.", bundle: .module)
                    .foregroundStyle(.secondary)
            } else {
                Section {
                    if let today = days.last {
                        StatRow(stats: [
                            Stat(value: "\(today.total)", label: Text("Reviews", bundle: .module)),
                            Stat(
                                value: Self.percent(today.accuracy),
                                label: Text("Right", bundle: .module)),
                            Stat(
                                value: "\(today.seconds / 60)",
                                label: Text("Minutes", bundle: .module)),
                            Stat(value: "\(streak)", label: Text("Days in a row", bundle: .module)),
                        ])
                    }
                } header: {
                    Text("Today", bundle: .module)
                }
                Section {
                    StatRow(stats: [
                        Stat(value: "\(total.answered)", label: Text("Reviews", bundle: .module)),
                        Stat(
                            value: Self.percent(total.accuracy),
                            label: Text("Right", bundle: .module)),
                        Stat(
                            value: Self.hours(total.seconds), label: Text("Hours", bundle: .module)),
                        Stat(value: "\(started)", label: Text("Words started", bundle: .module)),
                    ])
                } header: {
                    Text("All time", bundle: .module)
                }
                Section {
                    ReviewsChart(days: days)
                } header: {
                    Text("Reviews by day", bundle: .module)
                }
                Section {
                    AccuracyChart(days: days)
                } header: {
                    Text("Right by day", bundle: .module)
                }
                if snapshots.count >= 2 {
                    Section {
                        RankHistoryChart(snapshots: snapshots)
                    } header: {
                        Text("Ranks by day", bundle: .module)
                    }
                }
                Section {
                    StartedChart(days: days)
                } header: {
                    Text("Words started by day", bundle: .module)
                }
            }
        }
        .navigationTitle(Text("Progress", bundle: .module))
        .onAppear(perform: reload)
        .onReceive(Cards.changes(of: [.card])) { _ in reload() }
    }

    private func reload() {
        let cards = Cards.store?.cards() ?? []
        let now = Date()
        let from = Calendar.current.date(byAdding: .day, value: 1 - Self.daysShown, to: now) ?? now
        days = Progress.tallies(of: cards, from: from, to: now)
        streak = Progress.streak(of: cards, at: now)
        total = Progress.total(of: cards)
        started = cards.filter { $0.started != nil }.count
        snapshots = Array((Cards.snapshots?.snapshots() ?? []).suffix(Self.snapshotsShown))
    }

    private static func percent(_ fraction: Double?) -> String {
        fraction.map { "\(Int(($0 * 100).rounded()))%" } ?? "–"
    }

    private static func hours(_ seconds: Int) -> String {
        let hours = Double(seconds) / 3600
        return hours < 10 ? String(format: "%.1f", hours) : "\(Int(hours.rounded()))"
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

extension Question {
    /// The question's name, for a legend.
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

    static var colorScale: KeyValuePairs<String, Color> {
        [
            Question.reading.name: Question.reading.color,
            Question.meaning.name: Question.meaning.color,
            Question.pitch.name: Question.pitch.color,
        ]
    }
}

/// Answers a day, stacked by question.
private struct ReviewsChart: View {
    let days: [DayTally]

    var body: some View {
        Chart {
            ForEach(days, id: \.day) { day in
                ForEach(Question.allCases, id: \.self) { question in
                    BarMark(
                        x: .value(String(localized: "Day", bundle: .module), day.day, unit: .day),
                        y: .value(
                            String(localized: "Reviews", bundle: .module),
                            day.answered[question] ?? 0)
                    )
                    .foregroundStyle(
                        by: .value(String(localized: "Question", bundle: .module), question.name))
                }
            }
        }
        .chartForegroundStyleScale(Question.colorScale)
        .chartXAxis { AxisMarks(values: .stride(by: .day, count: 7)) }
        .frame(height: 160)
    }
}

/// The share right each day, one line a question; a day without the question has no point.
private struct AccuracyChart: View {
    let days: [DayTally]

    var body: some View {
        Chart {
            ForEach(Question.allCases, id: \.self) { question in
                ForEach(days, id: \.day) { day in
                    if let accuracy = day.accuracy(of: question) {
                        LineMark(
                            x: .value(
                                String(localized: "Day", bundle: .module), day.day, unit: .day),
                            y: .value(String(localized: "Right", bundle: .module), accuracy * 100),
                            series: .value(
                                String(localized: "Question", bundle: .module), question.name)
                        )
                        .foregroundStyle(
                            by: .value(
                                String(localized: "Question", bundle: .module), question.name)
                        )
                        .symbol(Circle())
                        .interpolationMethod(.monotone)
                    }
                }
            }
        }
        .chartForegroundStyleScale(Question.colorScale)
        .chartXScale(domain: days.span)
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(values: [0, 50, 100]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let percent = value.as(Int.self) { Text(verbatim: "\(percent)%") }
                }
            }
        }
        .chartXAxis { AxisMarks(values: .stride(by: .day, count: 7)) }
        .frame(height: 160)
    }
}

/// The cards at each rank as the days went, stacked from the nest up.
private struct RankHistoryChart: View {
    let snapshots: [RankSnapshot]

    var body: some View {
        Chart {
            ForEach(snapshots, id: \.day) { snapshot in
                ForEach(Rank.allCases, id: \.self) { rank in
                    AreaMark(
                        x: .value(
                            String(localized: "Day", bundle: .module), snapshot.day, unit: .day),
                        y: .value(
                            String(localized: "Cards", bundle: .module), snapshot.count(of: rank))
                    )
                    .foregroundStyle(
                        by: .value(String(localized: "Rank", bundle: .module), "\(rank.rawValue)"))
                }
            }
        }
        .chartForegroundStyleScale(
            domain: Rank.allCases.map { "\($0.rawValue)" }, range: Rank.allCases.map(\.color)
        )
        .chartLegend(.hidden)
        .frame(height: 180)
    }
}

/// The words a lesson started each day.
private struct StartedChart: View {
    let days: [DayTally]

    var body: some View {
        Chart(days, id: \.day) { day in
            BarMark(
                x: .value(String(localized: "Day", bundle: .module), day.day, unit: .day),
                y: .value(String(localized: "Words started", bundle: .module), day.started)
            )
            .foregroundStyle(Rank.hatchling.color)
        }
        .chartXAxis { AxisMarks(values: .stride(by: .day, count: 7)) }
        .frame(height: 120)
    }
}

extension Array where Element == DayTally {
    /// From the first day to the end of the last, so every chart spans the same days.
    fileprivate var span: ClosedRange<Date> {
        guard let first = first?.day, let last = last?.day else { return Date()...Date() }
        return first...(Calendar.current.date(byAdding: .day, value: 1, to: last) ?? last)
    }
}
