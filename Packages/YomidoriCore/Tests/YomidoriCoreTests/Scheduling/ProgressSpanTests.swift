import XCTest

@testable import YomidoriCore

final class ProgressSpanTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        calendar.firstWeekday = 2
        return calendar
    }

    private func date(_ string: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return formatter.date(from: string)!
    }

    func testASpanStartsAtTheFirstWholePeriodItCovers() {
        let now = date("2026-10-04T12:00:00+09:00")  // a Sunday
        // Four weeks of days: 27 days back, at that day's start.
        XCTAssertEqual(
            ProgressSpan.fourWeeks.start(now: now, earliest: nil, calendar: calendar),
            date("2026-09-07T00:00:00+09:00"))
        // Three months of weeks: 90 days back lands on a Monday's week (weeks start Monday).
        XCTAssertEqual(
            ProgressSpan.threeMonths.start(now: now, earliest: nil, calendar: calendar),
            date("2026-07-06T00:00:00+09:00"))
        // A year of months: the month 364 days back begins.
        XCTAssertEqual(
            ProgressSpan.year.start(now: now, earliest: nil, calendar: calendar),
            date("2025-10-01T00:00:00+09:00"))
        // Everything: from the earliest card's month, or this month with none.
        XCTAssertEqual(
            ProgressSpan.all.start(
                now: now, earliest: date("2026-03-15T10:00:00+09:00"), calendar: calendar),
            date("2026-03-01T00:00:00+09:00"))
        XCTAssertEqual(
            ProgressSpan.all.start(now: now, earliest: nil, calendar: calendar),
            date("2026-10-01T00:00:00+09:00"))
    }

    func testTheFingerIsOverTheLastPeriodStartingBeforeIt() {
        let days = [date("2026-10-01T00:00:00+09:00"), date("2026-10-02T00:00:00+09:00")]
        XCTAssertEqual(
            ProgressSpan.period(under: date("2026-10-01T15:00:00+09:00"), in: days) { $0 }, days[0])
        XCTAssertEqual(
            ProgressSpan.period(under: date("2026-10-03T15:00:00+09:00"), in: days) { $0 }, days[1])
        XCTAssertNil(ProgressSpan.period(under: date("2026-09-30T15:00:00+09:00"), in: days) { $0 })
        XCTAssertNil(ProgressSpan.period(under: nil, in: days) { $0 })
    }

    func testASlotsSharesStackFromTheLowestRankUp() {
        let slot = Upcoming.Slot(
            start: Date(), end: Date().addingTimeInterval(3600),
            counts: [.fledgling: 2, .hatchling: 3, .migrating: 1])
        XCTAssertEqual(slot.shares.map(\.rank), [.hatchling, .fledgling, .migrating])
        XCTAssertEqual(slot.shares.map { $0.from..<$0.to }, [0..<3, 3..<5, 5..<6])
    }
}
