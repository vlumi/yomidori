import XCTest

@testable import YomidoriCore

final class ReviewQueueTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func card(_ headword: String) -> Card {
        var card = Card(
            headword: headword, reading: "よみ", entryID: nil, sightings: [], created: now)
        card.start(at: now)
        return card
    }

    private func queue(_ headwords: [String]) -> ReviewQueue {
        ReviewQueue(headwords.map { ReviewItem(card: card($0), question: .reading) })
    }

    func testTheFrontIsUpAndOnlyTheFrontIsAnswered() {
        let queue = queue(["一", "二"])
        XCTAssertEqual(queue.current?.card.headword, "一")
        XCTAssertTrue(queue.isCurrent(ReviewItem(card: card("一"), question: .reading)))
        XCTAssertFalse(queue.isCurrent(ReviewItem(card: card("一"), question: .meaning)))
        XCTAssertFalse(queue.isCurrent(ReviewItem(card: card("二"), question: .reading)))
    }

    func testAMissComesBackThreeQuestionsOnOrAtTheEnd() {
        var queue = queue(["一", "二", "三", "四", "五"])
        let first = queue.current!
        queue.answered(first, grade: .again, card: nil)
        XCTAssertEqual(queue.items.map(\.card.headword), ["二", "三", "四", "一", "五"])
        var short = self.queue(["一", "二"])
        short.answered(short.current!, grade: .again, card: nil)
        XCTAssertEqual(short.items.map(\.card.headword), ["二", "一"])
        var alone = self.queue(["一"])
        alone.answered(alone.current!, grade: .again, card: nil)
        XCTAssertEqual(alone.items.map(\.card.headword), ["一"])
    }

    func testAQuestionAskedOnceIsARepeatAfter() {
        var queue = queue(["一", "二"])
        let first = queue.current!
        XCTAssertFalse(queue.isRepeat(first))
        queue.answered(first, grade: .again, card: nil)
        XCTAssertFalse(queue.isRepeat(queue.current!))
        XCTAssertTrue(queue.isRepeat(first))
        queue.answered(queue.current!, grade: .good, card: nil)
        XCTAssertEqual(queue.current?.card.headword, "一")
        XCTAssertTrue(queue.isRepeat(queue.current!))
        queue.answered(queue.current!, grade: .good, card: nil)
        XCTAssertTrue(queue.isEmpty)
    }

    func testTheCardAsAnsweredStandsInItsOtherQuestionsAndAMissCarriesIt() {
        var one = card("一")
        var queue = ReviewQueue([
            ReviewItem(card: one, question: .reading),
            ReviewItem(card: card("二"), question: .reading),
            ReviewItem(card: one, question: .meaning),
        ])
        one.answer(.reading, grade: .again, at: now)
        queue.answered(queue.current!, grade: .again, card: one)
        XCTAssertEqual(queue.items.map(\.question), [.reading, .meaning, .reading])
        XCTAssertEqual(
            queue.items.filter { $0.card.id == one.id }.map(\.card.review?.lapses), [1, 1])
        queue.remove(card: one.id)
        XCTAssertEqual(queue.items.map(\.card.headword), ["二"])
        XCTAssertEqual(queue.count, 1)
    }

    func testAnsweringWhatIsNotUpDoesNothing() {
        let now = Date()
        var first = Card(headword: "一", reading: "いち", entryID: nil, sightings: [], created: now)
        var second = Card(headword: "二", reading: "に", entryID: nil, sightings: [], created: now)
        first.start(at: now)
        second.start(at: now)
        var queue = ReviewQueue([
            ReviewItem(card: first, question: .reading),
            ReviewItem(card: second, question: .reading),
        ])
        queue.answered(ReviewItem(card: second, question: .reading), grade: .good, card: nil)
        XCTAssertEqual(queue.count, 2)
        var empty = ReviewQueue([])
        empty.answered(ReviewItem(card: first, question: .reading), grade: .good, card: nil)
        XCTAssertEqual(empty.count, 0)
    }
}
