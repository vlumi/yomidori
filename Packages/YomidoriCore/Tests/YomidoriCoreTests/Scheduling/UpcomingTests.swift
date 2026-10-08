import XCTest

@testable import YomidoriCore

final class UpcomingTests: XCTestCase {
    private func card(dueIn days: Int, from now: Date) -> Card {
        var card = Card(
            headword: "樹皮", reading: "じゅひ", entryID: nil, sightings: [], created: now)
        card.start(at: now)
        let state = ReviewState(
            stability: 10, difficulty: 5, due: now.addingTimeInterval(Double(days) * 86_400),
            lastReview: now, reviews: 1, lapses: 0)
        card.review = state
        card.meaningReview = state
        return card
    }

    func testAMonthAheadOneSlotADay() {
        let now = Date(timeIntervalSince1970: 1_790_000_000 + 43_200)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let card = card(dueIn: 20, from: now)
        let week = Upcoming.of([card], from: now, days: 7, calendar: calendar)
        XCTAssertEqual(week.slots.count, 28)
        XCTAssertEqual(week.questions, 0)
        XCTAssertEqual(week.later, 2)
        let month = Upcoming.of([card], from: now, days: 30, slotsPerDay: 1, calendar: calendar)
        XCTAssertEqual(month.slots.count, 30)
        XCTAssertEqual(month.days.count, 30)
        XCTAssertEqual(month.questions, 2)
        XCTAssertEqual(month.later, 0)
        XCTAssertEqual(month.days[20].questions, 2)
        XCTAssertEqual(month.slots[20].questions, 2)
        XCTAssertEqual(month.slots[20].end.timeIntervalSince(month.slots[20].start), 86_400)
    }
}
