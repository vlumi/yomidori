import Charts
import SwiftUI
import YomidoriCore

/// The week ahead as a picture: a bar for each quarter of a day, the questions that come
/// due in it stacked in the colors of their cards' ranks, a hairline between the days; a
/// finger on a bar (the pointer, on a Mac) reads it out above, and the whole week stands
/// there otherwise. What is overdue is in now's bar. Below, how many lie beyond.
struct UpcomingReviews: View {
    let upcoming: Upcoming
    @State private var selected: Date?
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 132

    /// A rank's share of a bar, stacked from the lowest rank up.
    private struct Share: Identifiable {
        let slot: Date
        let rank: Rank
        let from: Int
        let to: Int
        var id: String { "\(slot.timeIntervalSinceReferenceDate).\(rank.rawValue)" }
    }

    private var shares: [Share] {
        upcoming.slots.flatMap { slot in
            var stacked = 0
            return Rank.allCases.compactMap { rank -> Share? in
                guard let count = slot.counts[rank], count > 0 else { return nil }
                defer { stacked += count }
                return Share(slot: slot.start, rank: rank, from: stacked, to: stacked + count)
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
            Spacer(minLength: 0)
            ranks(of: chosen?.counts ?? upcoming.counts)
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
                        .font(.caption.monospacedDigit())
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
                            .font(.caption2)
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
        let color: Color = share.rank.color.opacity(dimmed ? 0.4 : 1)
        // A rectangle, not a bar: a bar has its width in points or in units of an axis,
        // and six hours is neither.
        let mark = RectangleMark(
            xStart: PlottableValue.value("From", from), xEnd: PlottableValue.value("To", to),
            yStart: PlottableValue.value("Stacked", share.from),
            yEnd: PlottableValue.value("Questions", share.to))
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
