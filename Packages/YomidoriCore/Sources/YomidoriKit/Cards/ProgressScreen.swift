import Charts
import SwiftUI
import YomidoriCore

/// The reviewing done: today and all time in numbers, and over a chosen span the answers
/// right and wrong, the ranks as they stood, and the words started. A finger on a chart
/// shows that period's numbers above it.
struct ProgressScreen: View {
    @State private var span: ProgressSpan = .fourWeeks
    @State private var question: Question?
    @State private var today: DayTally?
    @State private var buckets: [DayTally] = []
    @State private var snapshots: [RankSnapshot] = []
    @State private var streak = 0
    @State private var total = Progress.Total()
    @State private var started = 0
    /// Where the filters' row stands in the list and where the bar's safe area begins: once
    /// the row has scrolled up under the bar, a copy floats there until it comes back.
    @State private var filtersBottom: CGFloat = .infinity
    @State private var safeTop: CGFloat = 0

    private static let space = "progress"

    var body: some View {
        List {
            if total.answered == 0 && snapshots.count < 2 {
                Text("Nothing reviewed yet. Do a lesson, then a review.", bundle: .module)
                    .foregroundStyle(.secondary)
            } else {
                stats
                // The span and the question shape the charts, not the numbers above, so
                // they stand between the two; scrolled past, they float at the top.
                Section {
                    filters
                        .onGeometryChange(for: CGFloat.self) {
                            $0.frame(in: .named(Self.space)).maxY
                        } action: {
                            filtersBottom = $0
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
                Section {
                    AnswersChart(buckets: buckets, unit: span.unit, question: question)
                } header: {
                    Text("Reviews", bundle: .module)
                }
                if snapshots.count >= 2 {
                    Section {
                        RankHistoryChart(snapshots: snapshots, unit: span.unit, question: question)
                    } header: {
                        Text("Ranks", bundle: .module)
                    } footer: {
                        if question != nil, snapshots.filter(\.hasQuestions).count < 2 {
                            Text(
                                // swiftlint:disable:next line_length
                                "The ranks of each question are kept apart from now on; the chart fills in over the days.",
                                bundle: .module)
                        }
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
        .coordinateSpace(.named(Self.space))
        // The filters again, floating under the bar once their row has scrolled up under
        // it; an overlay, not an inset, so the list doesn't jump when they appear.
        .overlay(alignment: .top) {
            GeometryReader { proxy in
                let top = proxy.frame(in: .named(Self.space)).minY
                Color.clear
                    .onAppear { safeTop = top }
                    .onChange(of: top) { _, top in safeTop = top }
            }
            .frame(height: 0)
            if filtersBottom < safeTop {
                filters
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.bar)
            }
        }
        .onAppear(perform: reload)
        .onChange(of: span) { reload() }
        .onReceive(Cards.changes(of: [.card])) { _ in reload() }
    }

    private var filters: some View {
        VStack(spacing: 8) {
            Picker(selection: $span) {
                ForEach(ProgressSpan.allCases) { span in span.title.tag(span) }
            } label: {
                Text("Span", bundle: .module)
            }
            .pickerStyle(.segmented)
            QuestionPicker(question: $question)
        }
    }

    private var stats: some View {
        Group {
            Section {
                StatRow(stats: [
                    Stat(value: "\(today?.total ?? 0)", label: Text("Reviews", bundle: .module)),
                    Stat(
                        value: Percent.text(today?.accuracy),
                        label: Text("Correct", bundle: .module)),
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
                        value: Percent.text(total.accuracy), label: Text("Correct", bundle: .module)
                    ),
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
        let start = span.start(
            now: now,
            earliest: [Progress.earliest(of: cards), all.first?.day].compactMap { $0 }.min(),
            calendar: calendar)
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

enum Percent {
    static func text(_ fraction: Double?) -> String {
        fraction.map { "\(Int(($0 * 100).rounded()))%" } ?? "–"
    }
}

extension ProgressSpan {
    var title: Text {
        switch self {
        case .fourWeeks: return Text("4 weeks", bundle: .module)
        case .threeMonths: return Text("3 months", bundle: .module)
        case .year: return Text("Year", bundle: .module)
        case .all: return Text("All", bundle: .module)
        }
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
                        .font(.subheadline)
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

/// All the questions or one of them, for the charts to follow: the reading's, the meaning's
/// and the pitch's ranks climb apart.
struct QuestionPicker: View {
    @Binding var question: Question?

    var body: some View {
        Picker(selection: $question) {
            Text("All", bundle: .module).tag(Question?.none)
            ForEach(Question.allCases, id: \.self) { question in
                Text(verbatim: question.name).tag(Question?.some(question))
            }
        } label: {
            Text("Question", bundle: .module)
        }
        .pickerStyle(.segmented)
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
