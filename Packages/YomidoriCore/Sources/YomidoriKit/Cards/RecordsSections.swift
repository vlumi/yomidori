import SwiftUI
import YomidoriCore

/// The high marks of a day and of a week, each with when it was set.
struct ProgressRecords: Equatable {
    var reviewsInADay: Record?
    var timeInADay: Record?
    var reviewsInAWeek: Record?
    var timeInAWeek: Record?

    var isEmpty: Bool { reviewsInADay == nil && timeInADay == nil }

    static func of(days: [DayTally], calendar: Calendar) -> ProgressRecords {
        let weeks = Progress.rollUp(days, by: .weekOfYear, calendar: calendar)
        return ProgressRecords(
            reviewsInADay: Records.most(\.total, in: days),
            timeInADay: Records.most(\.seconds, in: days),
            reviewsInAWeek: Records.most(\.total, in: weeks),
            timeInAWeek: Records.most(\.seconds, in: weeks))
    }
}

/// The longest runs of studied days, the open one saying since when.
struct StreaksSection: View {
    let streaks: [Streak]
    let now: Date

    var body: some View {
        Section {
            ForEach(streaks, id: \.first) { run in
                LabeledContent {
                    if run.isOngoing(at: now) {
                        Text(
                            "Since \(run.first, format: .dateTime.year().month().day())",
                            bundle: .module)
                    } else {
                        Text(run.first..<run.last, format: .interval.year().month().day())
                    }
                } label: {
                    Text("\(run.days) days", bundle: .module)
                }
            }
        } header: {
            Text("Streaks", bundle: .module)
        } footer: {
            Text("Days in a row with a review, a lesson's practice included.", bundle: .module)
        }
    }
}

/// The most done in a day and in a week, with the day or the week it was done.
struct RecordsSection: View {
    let records: ProgressRecords
    let calendar: Calendar

    var body: some View {
        Section {
            if let record = records.reviewsInADay {
                row(Text("Reviews in a day", bundle: .module), "\(record.value)", day: record.day)
            }
            if let record = records.timeInADay {
                row(
                    Text("Time in a day", bundle: .module), StudyTimeChart.time(record.value),
                    day: record.day)
            }
            if let record = records.reviewsInAWeek {
                row(Text("Reviews in a week", bundle: .module), "\(record.value)", week: record.day)
            }
            if let record = records.timeInAWeek {
                row(
                    Text("Time in a week", bundle: .module), StudyTimeChart.time(record.value),
                    week: record.day)
            }
        } header: {
            Text("Records", bundle: .module)
        }
    }

    private func row(_ title: Text, _ value: String, day: Date) -> some View {
        LabeledContent {
            Text(verbatim: value).monospacedDigit()
        } label: {
            title
            Text(day, format: .dateTime.year().month().day())
        }
    }

    private func row(_ title: Text, _ value: String, week start: Date) -> some View {
        let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
        return LabeledContent {
            Text(verbatim: value).monospacedDigit()
        } label: {
            title
            Text(start..<end, format: .interval.year().month().day())
        }
    }
}
