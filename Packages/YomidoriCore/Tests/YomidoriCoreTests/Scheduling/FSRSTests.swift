import XCTest

@testable import YomidoriCore

final class FSRSTests: XCTestCase {
    private let day: TimeInterval = 86_400
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    func testAFirstGoodIsDueInThreeDaysAndAFirstAgainTomorrow() {
        let good = FSRS.review(nil, grade: .good, at: start)
        XCTAssertEqual(good.due.timeIntervalSince(start) / day, 3, accuracy: 0.001)
        XCTAssertEqual(good.reviews, 1)
        XCTAssertEqual(good.lapses, 0)
        let again = FSRS.review(nil, grade: .again, at: start)
        XCTAssertEqual(again.due.timeIntervalSince(start) / day, 1, accuracy: 0.001)
        XCTAssertEqual(again.lapses, 1)
        XCTAssertGreaterThan(again.difficulty, good.difficulty)
    }

    func testIntervalsGrowWithEachGoodAnswerOnTime() {
        var state = FSRS.review(nil, grade: .good, at: start)
        var intervals: [Double] = []
        for _ in 0..<4 {
            let at = state.due
            state = FSRS.review(state, grade: .good, at: at)
            intervals.append(state.due.timeIntervalSince(at) / day)
        }
        XCTAssertEqual(intervals, intervals.sorted())
        XCTAssertGreaterThan(intervals.last!, 20)
        XCTAssertEqual(state.reviews, 5)
    }

    func testALapseShrinksStabilityAndCountsItself() {
        var state = FSRS.review(nil, grade: .good, at: start)
        for _ in 0..<3 {
            state = FSRS.review(state, grade: .good, at: state.due)
        }
        let before = state.stability
        let intervalBefore = state.due.timeIntervalSince(state.lastReview)
        let lapsed = FSRS.review(state, grade: .again, at: state.due)
        XCTAssertLessThan(lapsed.stability, before)
        XCTAssertEqual(lapsed.lapses, 1)
        // A mature card that lapses comes back sooner than it was going to, not in a day:
        // FSRS keeps some of what was learned.
        XCTAssertLessThan(lapsed.due.timeIntervalSince(state.due), intervalBefore)
        XCTAssertGreaterThanOrEqual(lapsed.due.timeIntervalSince(state.due) / day, 1)
    }

    func testRetrievabilityIsFullAtReviewAndNinetyPercentAtTheDueDate() {
        let state = FSRS.review(nil, grade: .good, at: start)
        XCTAssertEqual(FSRS.retrievability(of: state, at: start), 1, accuracy: 0.0001)
        XCTAssertEqual(FSRS.retrievability(of: state, at: state.due), 0.9, accuracy: 0.02)
    }

    func testASameDayReviewUsesTheShortTermRule() {
        let state = FSRS.review(nil, grade: .good, at: start)
        let later = FSRS.review(state, grade: .good, at: start.addingTimeInterval(3600))
        XCTAssertGreaterThan(later.stability, state.stability)
        XCTAssertGreaterThanOrEqual(later.due.timeIntervalSince(later.lastReview) / day, 1)
    }

    func testDifficultyStaysWithinOneAndTen() {
        var state = FSRS.review(nil, grade: .again, at: start)
        for _ in 0..<30 {
            state = FSRS.review(state, grade: .again, at: state.due)
        }
        XCTAssertLessThanOrEqual(state.difficulty, 10)
        for _ in 0..<60 {
            state = FSRS.review(state, grade: .good, at: state.due)
        }
        XCTAssertGreaterThanOrEqual(state.difficulty, 1)
    }
}
