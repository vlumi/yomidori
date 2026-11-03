import Charts
import SwiftUI
import YomidoriCore

/// The time spent answering, for one question or all: each period's as a bar, or added up
/// as the span went, as a line; the caption gives the period under the finger, or the whole
/// span's. Which of the two is the section header's switch (`StudyTimeShape`).
struct StudyTimeChart: View {
    let buckets: [DayTally]
    let unit: Calendar.Component
    let question: Question?
    let cumulative: Bool
    @State private var selected: Date?

    private struct Point {
        let day: Date
        let seconds: Int
        var minutes: Double { Double(seconds) / 60 }
    }

    private var points: [Point] {
        let seconds =
            cumulative
            ? Progress.cumulativeSeconds(buckets, of: question)
            : buckets.map { $0.seconds(of: question) }
        return zip(buckets, seconds).map { Point(day: $0.day, seconds: $1) }
    }

    /// One question's color, or the app's green for all of them, as the Reviews chart.
    private var color: Color { question?.color ?? Palette.nightGreen }

    var body: some View {
        let points = points
        let picked = ProgressSpan.period(under: selected, in: points, start: \.day)
        let shown = picked?.seconds ?? buckets.map { $0.seconds(of: question) }.reduce(0, +)
        VStack(alignment: .leading, spacing: 8) {
            ChartCaption {
                if let question {
                    QuestionMark(question: question, size: 16)
                }
                if let picked {
                    Text(verbatim: Period.label(picked.day, unit: unit)).fontWeight(.semibold)
                }
                if cumulative, picked != nil {
                    Text("\(Self.time(shown)) so far", bundle: .module)
                } else {
                    Text(verbatim: Self.time(shown))
                }
            }
            // The shape decided outside the ForEach, and the chart made anew on a switch: marks
            // chosen inside it stayed as they were until the selection redrew them.
            Chart {
                if cumulative {
                    ForEach(points, id: \.day) { point in
                        AreaMark(
                            x: .value(String(localized: "Day", bundle: .module), point.day),
                            y: .value(String(localized: "Minutes", bundle: .module), point.minutes)
                        )
                        .foregroundStyle(color.opacity(0.2))
                        LineMark(
                            x: .value(String(localized: "Day", bundle: .module), point.day),
                            y: .value(String(localized: "Minutes", bundle: .module), point.minutes)
                        )
                        .foregroundStyle(color)
                    }
                } else {
                    if let today = points.last {
                        TodayColumn(day: today.day, unit: unit, empty: today.seconds == 0)
                    }
                    ForEach(points, id: \.day) { point in
                        BarMark(
                            x: .value(
                                String(localized: "Day", bundle: .module), point.day, unit: unit),
                            y: .value(String(localized: "Minutes", bundle: .module), point.minutes)
                        )
                        .foregroundStyle(color)
                    }
                }
                if let picked {
                    RuleMark(
                        x: .value(String(localized: "Day", bundle: .module), picked.day, unit: unit)
                    )
                    .foregroundStyle(.secondary.opacity(0.5))
                }
            }
            .id(cumulative)
            .chartXSelection(value: $selected)
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let minutes = value.as(Double.self) {
                            Text(verbatim: Self.axis(minutes: Int(minutes.rounded())))
                        }
                    }
                }
            }
            .frame(height: 140)
        }
    }

    /// "1 hr, 5 min", "12 min"; a span with nothing in it says "0 min".
    static func time(_ seconds: Int) -> String {
        Duration.seconds(seconds).formatted(
            .units(
                allowed: [.hours, .minutes], width: .abbreviated,
                zeroValueUnits: seconds < 60 ? .show(length: 1) : .hide))
    }

    /// "5m", "1h 30m": the axis has no room for words.
    static func axis(minutes: Int) -> String {
        guard minutes > 0 else { return "0" }
        return Duration.seconds(minutes * 60).formatted(
            .units(allowed: [.hours, .minutes], width: .narrow))
    }
}

/// The Time chart's switch, for its section header: each period's time, or the span's
/// added up.
struct StudyTimeShape: View {
    @Binding var cumulative: Bool
    let unit: Calendar.Component

    var body: some View {
        Picker(selection: $cumulative) {
            perPeriod.tag(false)
            Text("Added up", bundle: .module).tag(true)
        } label: {
            Text("Shape", bundle: .module)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .controlSize(.mini)
        .fixedSize()
    }

    private var perPeriod: Text {
        switch unit {
        case .day: return Text("Per day", bundle: .module)
        case .weekOfYear: return Text("Per week", bundle: .module)
        default: return Text("Per month", bundle: .module)
        }
    }
}
