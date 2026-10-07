import XCTest

@testable import YomidoriCore

final class RankTests: XCTestCase {
    func testTheBandsOnStability() {
        XCTAssertEqual(Rank(stability: 0.4), .hatchling)
        XCTAssertEqual(Rank(stability: 6.9), .hatchling)
        XCTAssertEqual(Rank(stability: 7), .chick)
        XCTAssertEqual(Rank(stability: 30), .fledgling)
        XCTAssertEqual(Rank(stability: 119), .fledgling)
        XCTAssertEqual(Rank(stability: 120), .flying)
        XCTAssertEqual(Rank(stability: 400), .migrating)
    }

    func testACardsRankFollowsItsStack() {
        var card = Card(
            headword: "樹皮", reading: "じゅひ", entryID: nil, sightings: [], created: Date())
        XCTAssertEqual(card.rank, .egg)
        card.start(at: Date())
        XCTAssertEqual(card.rank, .hatchling)
        card.answer(.reading, grade: .good, at: Date())
        XCTAssertEqual(card.rank, .hatchling)
        card.shelve()
        XCTAssertEqual(card.rank, .nest)
        XCTAssertTrue(Rank.egg < Rank.migrating)
        XCTAssertTrue(Rank.nest < Rank.egg)
        XCTAssertEqual(Rank.allCases.first, .nest)
    }

    func testTheNumbersCountFromTheEgg() {
        XCTAssertNil(Rank.nest.number)
        XCTAssertEqual(Rank.egg.number, 0)
        XCTAssertEqual(Rank.hatchling.number, 1)
        XCTAssertEqual(Rank.migrating.number, 5)
        XCTAssertEqual(Rank.allCases.map(\.index), Array(0..<Rank.allCases.count))
        let snapshot = RankSnapshot(day: Date(), counts: [1, 2, 3, 4, 5, 6, 7])
        XCTAssertEqual(snapshot.count(of: .nest), 1)
        XCTAssertEqual(snapshot.count(of: .egg), 2)
        XCTAssertEqual(snapshot.count(of: .migrating), 7)
    }

    func testEachQuestionHasARankOfItsOwn() {
        var card = Card(
            headword: "樹皮", reading: "じゅひ", entryID: nil, sightings: [], created: Date())
        XCTAssertEqual(card.rank(for: .meaning), .egg)
        card.start(at: Date())
        XCTAssertEqual(card.rank(for: .meaning), .hatchling)
        card.meaningReview = ReviewState(
            stability: 40, difficulty: 5, due: Date(), lastReview: Date(), reviews: 3, lapses: 0)
        XCTAssertEqual(card.rank(for: .meaning), .fledgling)
        XCTAssertEqual(card.rank(for: .reading), .hatchling)
        XCTAssertEqual(card.rank, card.rank(for: .reading))
        let snapshot = RankSnapshot.of([card], day: Date())
        XCTAssertEqual(snapshot.count(of: .fledgling, for: .meaning), 1)
        XCTAssertEqual(snapshot.count(of: .hatchling, for: .reading), 1)
        XCTAssertEqual(snapshot.count(of: .hatchling), 1)
        // An old snapshot, without the questions apart.
        let old = RankSnapshot(day: Date(), counts: [0, 0, 1, 0, 0, 0, 0])
        XCTAssertFalse(old.hasQuestions)
        XCTAssertNil(old.count(of: .hatchling, for: .reading))
        let upcoming = Upcoming.of([card], from: Date(), days: 1, question: .meaning)
        XCTAssertEqual(upcoming.questions, 1)
        XCTAssertEqual(upcoming.counts[.fledgling], 1)
        XCTAssertEqual(upcoming.questionCounts[.meaning], 1)
        let all = Upcoming.of([card], from: Date(), days: 1)
        XCTAssertEqual(all.questionCounts[.reading], 1)
        XCTAssertEqual(all.questionCounts[.meaning], 1)
        XCTAssertEqual(all.slots.first { $0.questions > 0 }?.questionShares.count, 2)
    }
}
