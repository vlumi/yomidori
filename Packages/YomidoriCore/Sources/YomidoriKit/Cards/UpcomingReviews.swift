import Charts
import SwiftUI
import YomidoriCore

/// The week ahead as a picture: a bar for each quarter of a day, the questions that come
/// due in it stacked in the colors of their ranks, each question's own, a hairline between
/// the days; a finger on a bar (the pointer, on a Mac) reads it out above, and the whole
/// week stands there otherwise. What is overdue is in now's bar. Below, how many lie beyond.
/// With more than one stacking, a chart each, the first full height and the rest smaller,
/// all under one readout and one finger: a bar touched in one is picked in all.
struct UpcomingReviews: View {
    let upcoming: Upcoming
    /// What colors the bars, a chart for each: the questions' ranks, what they ask.
    var stackings: [Stacking] = [.rank]
    @State private var selected: Date?
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 132

    /// The charts after the first: the same bars in other colors, a glance's worth.
    private static let secondaryHeight: CGFloat = 0.6

    enum Stacking {
        case rank
        case question
    }

    /// One part of one slot's bar, as the chart draws it: a rank's or a question's.
    private struct Share: Identifiable {
        let slot: Date
        let from: Int
        let to: Int
        let color: Color
        let key: String
        var id: String { "\(slot.timeIntervalSinceReferenceDate).\(key)" }
    }

    private func shares(_ stacking: Stacking) -> [Share] {
        upcoming.slots.flatMap { slot -> [Share] in
            switch stacking {
            case .rank:
                return slot.shares.map {
                    Share(
                        slot: slot.start, from: $0.from, to: $0.to, color: $0.rank.color,
                        key: "\($0.rank.rawValue)")
                }
            case .question:
                return slot.questionShares.map {
                    Share(
                        slot: slot.start, from: $0.from, to: $0.to, color: $0.question.color,
                        key: "q\($0.question.rawValue)")
                }
            }
        }
    }

    private var chosen: Upcoming.Slot? {
        selected.flatMap { date in upcoming.slots.first { $0.contains(date) } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            steady { readout(for: $0) }
            ForEach(Array(stackings.enumerated()), id: \.offset) { index, stacking in
                if index > 0 {
                    steady { slot in
                        HStack {
                            Spacer()
                            legend(stacking, of: slot).fixedSize()
                        }
                    }
                    .font(.callout.monospacedDigit())
                    .padding(.top, 4)
                }
                chart(stacking, height: index == 0 ? height : height * Self.secondaryHeight)
            }
            if upcoming.later > 0 {
                Text("\(upcoming.later) more after that", bundle: .module)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDays)
    }

    /// A readout as tall as the whole span's, whatever the finger is on: the span's, drawn
    /// unseen behind it, has every rank and question any slot has, so it is the tallest,
    /// and the charts below stay put while a finger moves over empty slots or few ranks.
    private func steady<Content: View>(@ViewBuilder _ content: (Upcoming.Slot?) -> Content)
        -> some View
    {
        ZStack(alignment: .topLeading) {
            content(nil).hidden().accessibilityHidden(true)
            content(chosen)
        }
    }

    /// The bar under the finger, else the week: its span, its count and its ranks.
    private func readout(for chosen: Upcoming.Slot?) -> some View {
        // On one line where it fits, on two where the ranks' numbers would wrap every word.
        FitsOrStacks(spacing: 8, trailingLast: true) {
            HStack(spacing: 10) {
                Group {
                    if let chosen {
                        Text(
                            verbatim: byDay
                                ? dayName(of: chosen.start)
                                : "\(dayName(of: chosen.start)) \(hours(of: chosen))")
                    } else {
                        Text("Next \(upcoming.days.count) days", bundle: .module)
                    }
                }
                .foregroundStyle(.secondary)
                Text(verbatim: "\(chosen?.questions ?? upcoming.questions)")
                    .fontWeight(.semibold)
            }
            .fixedSize()
            legend(stackings.first ?? .rank, of: chosen)
                .fixedSize()
        }
        .font(.callout.monospacedDigit())
        .frame(minHeight: 24)
    }

    /// A chart's key with the numbers of the bar under the finger, else of the whole span.
    @ViewBuilder
    private func legend(_ stacking: Stacking, of chosen: Upcoming.Slot?) -> some View {
        switch stacking {
        case .rank: ranks(of: chosen?.counts ?? upcoming.counts)
        case .question: questions(of: chosen?.questionCounts ?? upcoming.questionCounts)
        }
    }

    /// The ranks that come up, each as its dot and its number.
    private func ranks(of counts: [Rank: Int]) -> some View {
        HStack(spacing: 6) {
            ForEach(Rank.allCases.filter { (counts[$0] ?? 0) > 0 }, id: \.rawValue) { rank in
                HStack(spacing: 2) {
                    RankMark(rank: rank, size: 14)
                    Text(verbatim: "\(counts[rank] ?? 0)")
                        .font(.subheadline.monospacedDigit())
                }
            }
        }
    }

    /// The questions that come up, each as its mark and its number.
    private func questions(of counts: [Question: Int]) -> some View {
        HStack(spacing: 6) {
            ForEach(Question.allCases.filter { (counts[$0] ?? 0) > 0 }, id: \.self) { question in
                HStack(spacing: 2) {
                    QuestionMark(question: question, size: 14)
                    Text(verbatim: "\(counts[question] ?? 0)")
                        .font(.subheadline.monospacedDigit())
                }
            }
        }
    }

    private func chart(_ stacking: Stacking, height: CGFloat) -> some View {
        let from = upcoming.slots.first?.start ?? Date()
        let to = upcoming.slots.last?.end ?? from.addingTimeInterval(24 * 3600)
        let shares = shares(stacking)
        let chosenStart = chosen?.start
        return Chart {
            ForEach(shares) { share in
                bar(share, dimmed: chosenStart != nil && chosenStart != share.slot)
            }
            // A hairline where each day begins, after the first; each week's, by the day.
            ForEach(Array(lineDays.dropFirst()), id: \.self) { day in
                RuleMark(x: .value("Day", day))
                    .lineStyle(StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.secondary.opacity(0.5))
            }
        }
        .chartXScale(domain: from...to)
        .chartXSelection(value: $selected)
        .chartXAxis {
            // The day's name at its noon, no line of its own; by the day, each week's first.
            AxisMarks(values: lineDays.map { $0.addingTimeInterval(12 * 3600) }) { value in
                AxisValueLabel(anchor: .top) {
                    if let date = value.as(Date.self) {
                        Text(verbatim: dayName(of: date))
                            .font(.caption)
                            // Whole, past a narrow bar's width: the plot is padded for it.
                            .fixedSize()
                    }
                }
            }
        }
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...max(1, upcoming.slots.map(\.questions).max() ?? 1))
        // By the day, the first and last names hang past their narrow bars: room for them.
        .chartPlotStyle { plot in plot.padding(.horizontal, byDay ? 14 : 0) }
        .frame(height: height)
    }

    private func bar(_ share: Share, dimmed: Bool) -> some ChartContent {
        let from: Date = share.slot.addingTimeInterval(gap)
        let to: Date = slotEnd(share.slot).addingTimeInterval(-gap)
        let color: Color = share.color.opacity(dimmed ? 0.4 : 1)
        // A rectangle, not a bar: a bar has its width in points or in units of an axis,
        // and six hours is neither.
        let mark = RectangleMark(
            xStart: PlottableValue.value(String(localized: "From", bundle: .module), from),
            xEnd: PlottableValue.value(String(localized: "To", bundle: .module), to),
            yStart: PlottableValue.value(String(localized: "Stacked", bundle: .module), share.from),
            yEnd: PlottableValue.value(String(localized: "Questions", bundle: .module), share.to))
        return mark.foregroundStyle(color)
    }

    /// One slot a day: the month ahead, named by date rather than by hour.
    private var byDay: Bool {
        guard let slot = upcoming.slots.first else { return false }
        return slot.end.timeIntervalSince(slot.start) >= 24 * 3600 - 1
    }

    /// The days that get a line and a name: every day of a week, every seventh of a month.
    private var lineDays: [Date] {
        let starts = upcoming.days.map(\.day)
        return byDay ? starts.enumerated().filter { $0.offset % 7 == 0 }.map(\.element) : starts
    }

    /// A tenth of a slot, the room between bars.
    private var gap: TimeInterval {
        guard let slot = upcoming.slots.first else { return 6 * 360 }
        return slot.end.timeIntervalSince(slot.start) / 10
    }

    private func slotEnd(_ start: Date) -> Date {
        upcoming.slots.first { $0.start == start }?.end ?? start.addingTimeInterval(6 * 3600)
    }

    private func dayName(of date: Date) -> String {
        let day = Calendar.autoupdatingCurrent.startOfDay(for: date)
        switch upcoming.days.firstIndex(where: { $0.day == day }) {
        case 0: return String(localized: "Today", bundle: .module)
        case 1: return String(localized: "Tomorrow", bundle: .module)
        default:
            return byDay
                ? date.formatted(.dateTime.month(.abbreviated).day())
                : date.formatted(.dateTime.weekday(.abbreviated))
        }
    }

    private func hours(of slot: Upcoming.Slot) -> String {
        let from = slot.start.formatted(.dateTime.hour())
        let to = slot.end.formatted(.dateTime.hour())
        return "\(from)–\(to)"
    }

    private var accessibilityDays: Text {
        Text(
            verbatim: upcoming.days.map { "\(dayName(of: $0.day)) \($0.questions). " }.joined())
    }
}
