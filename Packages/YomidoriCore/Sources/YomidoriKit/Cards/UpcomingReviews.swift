import Charts
import SwiftUI
import YomidoriCore

/// The week ahead as a picture: a bar for each quarter of a day, the questions that come
/// due in it stacked in the colors of their cards' ranks, a hairline between the days; a
/// finger on a bar (the pointer, on a Mac) reads it out above, and the whole week stands
/// there otherwise. What is overdue is in now's bar. Below, how many lie beyond.
struct UpcomingReviews: View {
    let upcoming: Upcoming
    /// What colors the bars: the cards' ranks, or what each question asks.
    var stacking: Stacking = .rank
    @State private var selected: Date?
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 132

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

    private var shares: [Share] {
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
            readout
            chart
            if upcoming.later > 0 {
                Text("\(upcoming.later) more after that", bundle: .module)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDays)
    }

    /// The bar under the finger, else the week: its span, its count and its ranks.
    private var readout: some View {
        // On one line where it fits, on two where the ranks' numbers would wrap every word.
        FitsOrStacks(spacing: 8, trailingLast: true) {
            HStack(spacing: 10) {
                Group {
                    if let chosen {
                        Text(verbatim: "\(dayName(of: chosen.start)) \(hours(of: chosen))")
                    } else {
                        Text("Next \(upcoming.days.count) days", bundle: .module)
                    }
                }
                .foregroundStyle(.secondary)
                Text(verbatim: "\(chosen?.questions ?? upcoming.questions)")
                    .fontWeight(.semibold)
            }
            .fixedSize()
            Group {
                switch stacking {
                case .rank: ranks(of: chosen?.counts ?? upcoming.counts)
                case .question: questions(of: chosen?.questionCounts ?? upcoming.questionCounts)
                }
            }
            .fixedSize()
        }
        .font(.callout.monospacedDigit())
        .frame(minHeight: 24)
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

    /// The questions that come up, each as a dot of its color and its number.
    private func questions(of counts: [Question: Int]) -> some View {
        HStack(spacing: 6) {
            ForEach(Question.allCases.filter { (counts[$0] ?? 0) > 0 }, id: \.self) { question in
                HStack(spacing: 2) {
                    Circle().fill(question.color).frame(width: 10, height: 10)
                        .accessibilityLabel(Text(verbatim: question.name))
                    Text(verbatim: "\(counts[question] ?? 0)")
                        .font(.subheadline.monospacedDigit())
                }
            }
        }
    }

    private var chart: some View {
        let dayStarts = upcoming.days.map(\.day)
        let from = upcoming.slots.first?.start ?? Date()
        let to = upcoming.slots.last?.end ?? from.addingTimeInterval(24 * 3600)
        let shares = shares
        let chosenStart = chosen?.start
        return Chart {
            ForEach(shares) { share in
                bar(share, dimmed: chosenStart != nil && chosenStart != share.slot)
            }
            // A hairline where each day begins, after the first.
            ForEach(Array(dayStarts.dropFirst()), id: \.self) { day in
                RuleMark(x: .value("Day", day))
                    .lineStyle(StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.secondary.opacity(0.5))
            }
        }
        .chartXScale(domain: from...to)
        .chartXSelection(value: $selected)
        .chartXAxis {
            // The day's name at its noon, no line of its own.
            AxisMarks(values: dayStarts.map { $0.addingTimeInterval(12 * 3600) }) { value in
                AxisValueLabel(anchor: .top) {
                    if let date = value.as(Date.self) {
                        Text(verbatim: dayName(of: date))
                            .font(.caption)
                    }
                }
            }
        }
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...max(1, upcoming.slots.map(\.questions).max() ?? 1))
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

    /// A tenth of a quarter day, the room between bars.
    private var gap: TimeInterval { 6 * 3600 / 10 }

    private func slotEnd(_ start: Date) -> Date {
        upcoming.slots.first { $0.start == start }?.end ?? start.addingTimeInterval(6 * 3600)
    }

    private func dayName(of date: Date) -> String {
        let day = Calendar.current.startOfDay(for: date)
        switch upcoming.days.firstIndex { $0.day == day } {
        case 0: return String(localized: "Today", bundle: .module)
        case 1: return String(localized: "Tomorrow", bundle: .module)
        default: return date.formatted(.dateTime.weekday(.abbreviated))
        }
    }

    private func hours(of slot: Upcoming.Slot) -> String {
        let from = slot.start.formatted(.dateTime.hour())
        let to = slot.end.formatted(.dateTime.hour())
        return "\(from)–\(to)"
    }

    private var accessibilityDays: Text {
        upcoming.days.enumerated().reduce(Text(verbatim: "")) { text, item in
            text + Text(verbatim: "\(dayName(of: item.element.day)) \(item.element.questions). ")
        }
    }
}
