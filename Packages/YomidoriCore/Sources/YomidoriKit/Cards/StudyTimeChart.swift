import Charts
import SwiftUI
import YomidoriCore

/// The time spent answering, for one question or all: each period's as a bar, or added up
/// as the span went, as a line; the caption gives the period under the finger, or the whole
/// span's.
struct StudyTimeChart: View {
    let buckets: [DayTally]
    let unit: Calendar.Component
    let question: Question?
    @AppStorage(SettingsKey.studyTimeCumulative) private var cumulative = false
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

    private var color: Color { question?.color ?? Rank.migrating.color }

    var body: some View {
        let points = points
        let picked = ProgressSpan.period(under: selected, in: points, start: \.day)
        let shown = picked?.seconds ?? buckets.map { $0.seconds(of: question) }.reduce(0, +)
        VStack(alignment: .leading, spacing: 8) {
            FitsOrStacks(spacing: 8, trailingLast: true) {
                ChartCaption {
                    if let picked {
                        Text(verbatim: Period.label(picked.day, unit: unit)).fontWeight(.semibold)
                    }
                    if cumulative, picked != nil {
                        Text("\(Self.time(shown)) so far", bundle: .module)
                    } else {
                        Text(verbatim: Self.time(shown))
                    }
                }
                .fixedSize()
                Picker(selection: $cumulative) {
                    perPeriod.tag(false)
                    Text("Added up", bundle: .module).tag(true)
                } label: {
                    Text("Shape", bundle: .module)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
                .fixedSize()
            }
            Chart {
                ForEach(points, id: \.day) { point in
                    if cumulative {
                        AreaMark(
                            x: .value(String(localized: "Day", bundle: .module), point.day),
                            y: .value(
                                String(localized: "Minutes", bundle: .module), point.minutes)
                        )
                        .foregroundStyle(color.opacity(0.2))
                        LineMark(
                            x: .value(String(localized: "Day", bundle: .module), point.day),
                            y: .value(
                                String(localized: "Minutes", bundle: .module), point.minutes)
                        )
                        .foregroundStyle(color)
                    } else {
                        BarMark(
                            x: .value(
                                String(localized: "Day", bundle: .module), point.day, unit: unit),
                            y: .value(
                                String(localized: "Minutes", bundle: .module), point.minutes)
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

    private var perPeriod: Text {
        switch unit {
        case .day: return Text("Per day", bundle: .module)
        case .weekOfYear: return Text("Per week", bundle: .module)
        default: return Text("Per month", bundle: .module)
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
