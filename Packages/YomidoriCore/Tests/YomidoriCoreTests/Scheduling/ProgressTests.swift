import XCTest

@testable import YomidoriCore

final class ProgressTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }

    /// Noon on a day, Tokyo time.
    private func noon(_ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: 12))!
    }

    private func card(_ word: String, started: Date? = nil) -> Card {
        var card = Card(
            headword: word, reading: word, entryID: nil, sightings: [], created: noon(1))
        if let started { card.start(at: started) }
        return card
    }

    func testAnswersAreTalliedByDayQuestionAndGrade() {
        var bark = card("樹皮", started: noon(2))
        bark.answer(.reading, grade: .good, at: noon(3), seconds: 10)
        bark.answer(.meaning, grade: .again, at: noon(3), seconds: 20)
        bark.answer(.pitch, grade: .good, at: noon(3), reconciled: true, seconds: 5)
        // Just before midnight belongs to the 4th in Tokyo.
        bark.answer(.reading, grade: .good, at: noon(4).addingTimeInterval(11 * 3600), seconds: 7)
        let room = card("部屋", started: noon(3))
        let days = Progress.tallies(
            of: [bark, room], from: noon(2), to: noon(5), calendar: calendar)
        XCTAssertEqual(days.map(\.day), [2, 3, 4, 5].map { calendar.startOfDay(for: noon($0)) })
        XCTAssertEqual(days[0].total, 0)
        XCTAssertEqual(days[0].started, 1)
        XCTAssertEqual(days[1].answered, [.reading: 1, .meaning: 1, .pitch: 1])
        XCTAssertEqual(days[1].right, [.reading: 1, .pitch: 1])
        XCTAssertEqual(days[1].seconds, 35)
        XCTAssertEqual(days[1].started, 1)
        XCTAssertEqual(days[1].accuracy, 2.0 / 3.0)
        XCTAssertEqual(days[1].accuracy(of: .reading), 1)
        XCTAssertEqual(days[1].accuracy(of: .meaning), 0)
        XCTAssertEqual(days[2].answered, [.reading: 1])
        XCTAssertEqual(days[2].seconds, 7)
        XCTAssertNil(days[3].accuracy)
        XCTAssertTrue(Progress.tallies(of: [bark], from: noon(5), to: noon(4)).isEmpty)
        let total = Progress.total(of: [bark, room])
        XCTAssertEqual(total.answered, 4)
        XCTAssertEqual(total.right, 3)
        XCTAssertEqual(total.seconds, 42)
    }

    func testDaysRollUpIntoWeeksAndMonths() {
        var bark = card("樹皮", started: noon(1))
        // Tokyo's calendar starts the week on Sunday: Sept 6 and 12 are one week, 13 the next.
        bark.answer(.reading, grade: .good, at: noon(6), seconds: 5)
        bark.answer(.meaning, grade: .again, at: noon(12), seconds: 7)
        bark.answer(.pitch, grade: .good, at: noon(13), seconds: 9)
        let days = Progress.tallies(of: [bark], from: noon(1), to: noon(20), calendar: calendar)
        let weeks = Progress.rollUp(days, by: .weekOfYear, calendar: calendar)
        XCTAssertEqual(weeks.count, 4)
        let second = weeks[1]
        XCTAssertEqual(second.day, calendar.startOfDay(for: noon(6)))
        XCTAssertEqual(second.answered, [.reading: 1, .meaning: 1])
        XCTAssertEqual(second.right, [.reading: 1])
        XCTAssertEqual(second.seconds, 12)
        XCTAssertEqual(weeks[2].answered, [.pitch: 1])
        XCTAssertEqual(weeks[0].started, 1)
        let months = Progress.rollUp(days, by: .month, calendar: calendar)
        XCTAssertEqual(months.count, 1)
        XCTAssertEqual(months[0].total, 3)
        XCTAssertEqual(Progress.rollUp(days, by: .day, calendar: calendar), days)
        XCTAssertEqual(Progress.earliest(of: [bark]), noon(1))
        XCTAssertNil(Progress.earliest(of: [card("部屋")]))
    }

    func testSnapshotsThinToTheFirstOfEachPeriod() {
        let snapshots = [1, 6, 8, 13, 14].map { day in
            RankSnapshot(day: calendar.startOfDay(for: noon(day)), counts: [0, day, 0, 0, 0, 0, 0])
        }
        let weekly = RankSnapshot.thinned(snapshots.reversed(), by: .weekOfYear, calendar: calendar)
        XCTAssertEqual(weekly.map { $0.count(of: .egg) }, [1, 6, 13])
        XCTAssertEqual(RankSnapshot.thinned(snapshots, by: .month, calendar: calendar).count, 1)
        XCTAssertEqual(RankSnapshot.thinned(snapshots, by: .day, calendar: calendar), snapshots)
        XCTAssertEqual(snapshots[1].total, 6)
    }

    func testTheStreakCountsDaysInARowAndForgivesToday() {
        var bark = card("樹皮", started: noon(1))
        for day in [3, 4, 5] { bark.answer(.reading, grade: .good, at: noon(day)) }
        XCTAssertEqual(Progress.streak(of: [bark], at: noon(5), calendar: calendar), 3)
        // Nothing yet today: yesterday's run still stands.
        XCTAssertEqual(Progress.streak(of: [bark], at: noon(6), calendar: calendar), 3)
        // A day missed ends it.
        XCTAssertEqual(Progress.streak(of: [bark], at: noon(7), calendar: calendar), 0)
        XCTAssertEqual(Progress.streak(of: [], at: noon(7), calendar: calendar), 0)
    }

    func testAnEntrysSecondsAreCappedAndReadAsZeroWhenMissing() throws {
        XCTAssertEqual(
            ReviewEntry(
                date: noon(1), question: .reading, grade: .good, reconciled: false,
                seconds: 900
            ).seconds,
            ReviewEntry.longestCounted)
        XCTAssertEqual(
            ReviewEntry(
                date: noon(1), question: .reading, grade: .good, reconciled: false,
                seconds: -3
            ).seconds, 0)
        let old = Data(
            """
            {"date":"2026-09-01T03:00:00Z","question":0,"grade":"good","reconciled":false}
            """.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entry = try decoder.decode(ReviewEntry.self, from: old)
        XCTAssertEqual(entry.seconds, 0)
        XCTAssertEqual(entry.grade, .good)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let back = try decoder.decode(
            ReviewEntry.self,
            from: try encoder.encode(
                ReviewEntry(
                    date: noon(1), question: .pitch, grade: .again, reconciled: true,
                    seconds: 12)))
        XCTAssertEqual(back.seconds, 12)
    }
}
