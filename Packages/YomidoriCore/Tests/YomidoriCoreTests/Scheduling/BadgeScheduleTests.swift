import XCTest

@testable import YomidoriCore

final class BadgeScheduleTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// 33 minutes 20 seconds past a whole hour (UTC).
    private let now = Date(timeIntervalSince1970: 1_789_992_000 + 33 * 60 + 20)

    func testTheCountStepsUpAtTheEndOfEachHourSomethingComesDue() {
        let dates = [
            now.addingTimeInterval(-60),  // due already: counted in the base
            now.addingTimeInterval(600),  // :43, stepped at the next hour
            now.addingTimeInterval(900),  // :48, the same step
            now.addingTimeInterval(3 * 3600),  // three hours on, stepped an hour after
        ]
        let steps = BadgeSchedule.steps(dueDates: dates, after: now, base: 5, calendar: calendar)
        XCTAssertEqual(steps.map(\.count), [7, 8])
        let hour = calendar.component(.hour, from: now)
        XCTAssertEqual(calendar.component(.minute, from: now), 33)
        XCTAssertEqual(
            steps.map { calendar.component(.hour, from: $0.date) }, [hour + 1, hour + 4])
        XCTAssertTrue(steps.allSatisfy { calendar.component(.minute, from: $0.date) == 0 })
        XCTAssertTrue(steps.allSatisfy { $0.date > now })
    }

    func testOnlyTheFirstStepsAreKept() {
        let dates = (1...100).map { now.addingTimeInterval(Double($0) * 7200) }
        let steps = BadgeSchedule.steps(
            dueDates: dates, after: now, base: 0, limit: 60, calendar: calendar)
        XCTAssertEqual(steps.count, 60)
        XCTAssertEqual(steps.last?.count, 60)
        XCTAssertTrue(BadgeSchedule.steps(dueDates: [], after: now, base: 3).isEmpty)
    }

    func testACardsUpcomingQuestionsAreThoseInReviewAndAsked() {
        var card = Card(headword: "樹皮", reading: "じゅひ", entryID: nil, sightings: [], created: now)
        XCTAssertEqual(card.upcomingDue(after: now, asksPitch: true), [])
        card.start(at: now)
        card.answer(.reading, grade: .good, at: now)
        card.answer(.pitch, grade: .good, at: now)
        let reading = card.review!.due
        let pitch = card.pitchReview!.due
        // The meaning, never answered, is due now: not upcoming.
        XCTAssertEqual(Set(card.upcomingDue(after: now, asksPitch: true)), [reading, pitch])
        XCTAssertEqual(card.upcomingDue(after: now, asksPitch: false), [reading])
        card.shelve()
        XCTAssertEqual(card.upcomingDue(after: now, asksPitch: true), [])
    }

    func testTheNextDueIsTheEarliestUpcomingAcrossTheCards() {
        var bark = Card(headword: "樹皮", reading: "じゅひ", entryID: nil, sightings: [], created: now)
        var room = Card(headword: "部屋", reading: "へや", entryID: nil, sightings: [], created: now)
        XCTAssertNil(Card.nextDue(among: [bark, room], after: now, asksPitch: { _ in true }))
        bark.start(at: now)
        bark.answer(.reading, grade: .good, at: now)
        room.start(at: now.addingTimeInterval(-3 * 86400))
        room.answer(.reading, grade: .again, at: now)
        let soonest = min(bark.review!.due, room.review!.due)
        XCTAssertEqual(
            Card.nextDue(among: [bark, room], after: now, asksPitch: { _ in false }), soonest)
        // Once the clock has passed it, the next one after that.
        XCTAssertEqual(
            Card.nextDue(among: [bark, room], after: soonest, asksPitch: { _ in false }),
            max(bark.review!.due, room.review!.due))
    }
}
