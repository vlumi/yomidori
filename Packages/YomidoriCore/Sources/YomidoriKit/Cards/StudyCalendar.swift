import SwiftUI
import YomidoriCore

/// The last year of days as a grid, a week a column, a studied day's square filled and the
/// fuller the more was answered. The caption counts the last 30 days; a finger on a square
/// names that day and its reviews instead.
struct StudyCalendar: View {
    /// Every day up to today, as `Progress.tallies` gives them.
    let days: [DayTally]
    let now: Date
    let calendar: Calendar
    @State private var width: CGFloat = 0
    @State private var picked: Date?

    private static let weeks = 52
    private static let gap: CGFloat = 2
    private static let labels: CGFloat = 16
    private static let lastDays = 30

    private var byDay: [Date: DayTally] {
        Dictionary(days.map { ($0.day, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// The first column's first day: the week holding the day a year back.
    private var firstDay: Date {
        let today = calendar.startOfDay(for: now)
        let back = calendar.date(byAdding: .day, value: -(Self.weeks * 7 - 1), to: today) ?? today
        return calendar.dateInterval(of: .weekOfYear, for: back)?.start ?? back
    }

    private var columns: Int {
        let today = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: firstDay, to: today).day ?? 0
        return days / 7 + 1
    }

    private var cell: CGFloat {
        guard width > 0 else { return 0 }
        return (width - Self.gap * CGFloat(columns - 1)) / CGFloat(columns)
    }

    private var height: CGFloat { Self.labels + cell * 7 + Self.gap * 6 }

    private var studiedLately: Int {
        let today = calendar.startOfDay(for: now)
        return (0..<Self.lastDays).filter { back in
            guard let day = calendar.date(byAdding: .day, value: -back, to: today) else {
                return false
            }
            return (byDay[day]?.total ?? 0) > 0
        }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ChartCaption {
                if let picked {
                    Text(verbatim: Period.label(picked, unit: .day, calendar: calendar))
                        .fontWeight(.semibold)
                    Text("\(byDay[picked]?.total ?? 0) reviews", bundle: .module)
                } else {
                    Text(
                        "Studied \(studiedLately) of the last \(Self.lastDays) days",
                        bundle: .module)
                }
            }
            grid
        }
    }

    private var grid: some View {
        Canvas { context, _ in draw(in: &context) }
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .onGeometryChange(for: CGFloat.self) {
                $0.size.width
            } action: {
                width = $0
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { picked = day(at: $0.location) }
                    .onEnded { _ in picked = nil }
            )
            .accessibilityHidden(true)
    }

    private func origin(column: Int, row: Int) -> CGPoint {
        CGPoint(
            x: CGFloat(column) * (cell + Self.gap),
            y: Self.labels + CGFloat(row) * (cell + Self.gap))
    }

    private func day(at point: CGPoint) -> Date? {
        guard cell > 0, point.y >= Self.labels else { return nil }
        let column = Int(point.x / (cell + Self.gap))
        let row = Int((point.y - Self.labels) / (cell + Self.gap))
        guard (0..<columns).contains(column), (0..<7).contains(row) else { return nil }
        guard let day = calendar.date(byAdding: .day, value: column * 7 + row, to: firstDay),
            day <= calendar.startOfDay(for: now)
        else { return nil }
        return day
    }

    private func draw(in context: inout GraphicsContext) {
        guard cell > 0 else { return }
        let today = calendar.startOfDay(for: now)
        let most = days.map(\.total).max() ?? 0
        var lastLabel = -3
        var day = firstDay
        var index = 0
        while day <= today {
            let column = index / 7
            let row = index % 7
            let total = byDay[day]?.total ?? 0
            let square = CGRect(
                origin: origin(column: column, row: row), size: CGSize(width: cell, height: cell))
            let fill: Color
            if total > 0, most > 0 {
                fill = Palette.nightGreen.opacity(0.35 + 0.65 * Double(total) / Double(most))
            } else {
                fill = Color.primary.opacity(0.08)
            }
            context.fill(Path(roundedRect: square, cornerRadius: cell / 4), with: .color(fill))
            if picked == day {
                context.stroke(
                    Path(roundedRect: square.insetBy(dx: -1, dy: -1), cornerRadius: cell / 4),
                    with: .color(.primary), lineWidth: 1.5)
            }
            // The month's name over the column its first day falls in, unless the last one
            // is too close to read apart.
            if calendar.component(.day, from: day) == 1, column - lastLabel >= 3 {
                let name = day.formatted(.dateTime.month(.abbreviated))
                context.draw(
                    Text(verbatim: name).font(.caption2).foregroundStyle(.secondary),
                    at: CGPoint(x: origin(column: column, row: 0).x, y: 0), anchor: .topLeading)
                lastLabel = column
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
            index += 1
        }
    }
}
