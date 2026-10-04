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
}
