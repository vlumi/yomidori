import SwiftUI
import YomidoriCore

/// The week ahead in numbers: the questions that come due each day, today's with what is
/// overdue, a thin bar beside each so a wall is seen coming; and how many lie beyond.
struct UpcomingReviews: View {
    let upcoming: Upcoming
    @ScaledMetric(relativeTo: .body) private var dayWidth: CGFloat = 96
    @ScaledMetric(relativeTo: .body) private var countWidth: CGFloat = 40

    var body: some View {
        ForEach(Array(upcoming.days.enumerated()), id: \.element.id) { index, day in
            HStack(spacing: 12) {
                name(of: day.day, at: index)
                    .frame(width: dayWidth, alignment: .leading)
                bar(day.questions)
                Text(verbatim: "\(day.questions)")
                    .font(.body.monospacedDigit())
                    .foregroundStyle(day.questions < 1 ? .secondary : .primary)
                    .frame(width: countWidth, alignment: .trailing)
            }
            .accessibilityElement(children: .combine)
        }
        if upcoming.later > 0 {
            Text("\(upcoming.later) more after that", bundle: .module)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private func name(of day: Date, at index: Int) -> some View {
        switch index {
        case 0: Text("Today", bundle: .module)
        case 1: Text("Tomorrow", bundle: .module)
        default: Text(day, format: .dateTime.weekday(.abbreviated).day())
        }
    }

    /// The day's share of the week's fullest day.
    private func bar(_ count: Int) -> some View {
        GeometryReader { geometry in
            let share = upcoming.most > 0 ? CGFloat(count) / CGFloat(upcoming.most) : 0
            Capsule()
                .fill(Palette.nightGreen.opacity(0.7))
                .frame(width: max(count > 0 ? 3 : 0, geometry.size.width * share), height: 6)
                .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(height: 12)
        .accessibilityHidden(true)
    }
}
