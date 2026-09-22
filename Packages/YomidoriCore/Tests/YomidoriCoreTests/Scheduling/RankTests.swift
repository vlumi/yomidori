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
    }
}
