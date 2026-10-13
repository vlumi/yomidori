import XCTest

@testable import YomidoriCore

/// A word written in kana alone — うんざり — has no reading to ask.
final class KanaCardTests: XCTestCase {
    private func card(_ headword: String, _ reading: String) -> Card {
        var card = Card(
            headword: headword, reading: reading, entryID: nil, sightings: [], created: Date())
        card.start(at: Date())
        return card
    }

    func testAKanaWordIsNotAskedItsReading() {
        let kana = card("うんざり", "うんざり")
        XCTAssertFalse(kana.asksReading)
        XCTAssertEqual(kana.dueQuestions(at: Date(), asksPitch: true), [.meaning, .pitch])
        XCTAssertEqual(kana.questions(asksPitch: false), [.meaning])
        let kanji = card("面皰", "にきび")
        XCTAssertTrue(kanji.asksReading)
        XCTAssertEqual(kanji.dueQuestions(at: Date(), asksPitch: false), [.reading, .meaning])
    }

    func testAReadingOnceAskedIsAskedNoMoreAndRanksNothing() {
        var kana = card("うんざり", "うんざり")
        let now = Date()
        // A reading answered before the rule, well into the future; the meaning due now.
        kana.setState(
            ReviewState(
                stability: 100, difficulty: 5, due: now.addingTimeInterval(86_400 * 50),
                lastReview: now, reviews: 3, lapses: 0), for: .reading)
        kana.setState(
            ReviewState(
                stability: 1, difficulty: 5, due: now, lastReview: now, reviews: 1, lapses: 0),
            for: .meaning)
        XCTAssertEqual(kana.dueQuestions(at: now, asksPitch: false), [.meaning])
        // The card's rank is its meaning's, not held up by the reading's old stability.
        XCTAssertEqual(kana.rank, .hatchling)
        XCTAssertEqual(kana.upcomingDue(after: now, asksPitch: false), [])
        let upcoming = Upcoming.of([kana], from: now, days: 60)
        XCTAssertEqual(upcoming.questionCounts[.reading] ?? 0, 0)
        XCTAssertEqual(upcoming.questionCounts[.meaning], 1)
        let snapshot = RankSnapshot.of([kana], day: now)
        XCTAssertEqual(snapshot.count(of: .flying, for: .reading), 0)
        XCTAssertEqual(snapshot.count(of: .hatchling, for: .meaning), 1)
    }
}
