import XCTest

@testable import YomidoriCore

final class RecordsTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }

    private func noon(_ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: 12))!
    }

    private func start(_ day: Int) -> Date { calendar.startOfDay(for: noon(day)) }

    private func card(answeredOn days: [Int]) -> Card {
        var card = Card(
            headword: "樹皮", reading: "じゅひ", entryID: nil, sightings: [], created: noon(1))
        card.start(at: noon(1))
        for day in days { card.answer(.reading, grade: .good, at: noon(day), seconds: 10) }
        return card
    }

    func testStreaksAreEveryRunLongestFirstAndLatestAmongEquals() {
        // Runs of 2 (1–2), 3 (5–7), 1 (10) and 2 (12–13); the second card's answers fall
        // into the same days.
        let cards = [card(answeredOn: [1, 2, 5, 6, 7, 10, 12, 13]), card(answeredOn: [6, 13])]
        let runs = Records.streaks(of: cards, calendar: calendar)
        XCTAssertEqual(
            runs,
            [
                Streak(first: start(5), last: start(7), days: 3),
                Streak(first: start(12), last: start(13), days: 2),
                Streak(first: start(1), last: start(2), days: 2),
                Streak(first: start(10), last: start(10), days: 1),
            ])
        XCTAssertEqual(Records.streaks(of: [], calendar: calendar), [])
    }

    func testARunIsOngoingThroughTodayAndTheDayAfterItsLast() {
        let run = Streak(first: start(5), last: start(7), days: 3)
        XCTAssertTrue(run.isOngoing(at: noon(7), calendar: calendar))
        XCTAssertTrue(run.isOngoing(at: noon(8), calendar: calendar))
        XCTAssertFalse(run.isOngoing(at: noon(9), calendar: calendar))
        XCTAssertFalse(run.isOngoing(at: noon(6), calendar: calendar))
    }

    func testTheCurrentStreakIsTheOngoingRun() {
        let cards = [card(answeredOn: [1, 2, 5, 6, 7])]
        XCTAssertEqual(Progress.streak(of: cards, at: noon(8), calendar: calendar), 3)
        XCTAssertEqual(Progress.streak(of: cards, at: noon(9), calendar: calendar), 0)
    }

    func testARecordIsTheFirstPeriodToReachTheHighestNumber() {
        let cards = [card(answeredOn: [1, 3, 3, 3, 5, 5, 5, 9])]
        let days = Progress.tallies(of: cards, from: noon(1), to: noon(9), calendar: calendar)
        XCTAssertEqual(Records.most(\.total, in: days), Record(value: 3, day: start(3)))
        XCTAssertEqual(Records.most(\.seconds, in: days), Record(value: 30, day: start(3)))
        // Weeks start on Sunday in the Gregorian calendar: the 1st to the 5th are one week.
        let weeks = Progress.rollUp(days, by: .weekOfYear, calendar: calendar)
        XCTAssertEqual(
            Records.most(\.total, in: weeks),
            Record(value: 7, day: calendar.dateInterval(of: .weekOfYear, for: noon(1))!.start))
        XCTAssertNil(Records.most(\.started, in: []))
        XCTAssertNil(Records.most(\.total, in: [DayTally(day: start(1))]))
    }
}
