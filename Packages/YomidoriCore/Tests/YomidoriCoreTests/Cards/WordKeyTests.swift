import XCTest

@testable import YomidoriCore

final class WordKeyTests: XCTestCase {
    func testACardsIDIsItsWordsForGood() {
        // Fixed: a change here changes every card's id, and sync loses track of them all.
        XCTAssertEqual(WordKey.of(headword: "樹皮", reading: "じゅひ"), "樹皮 じゅひ")
        XCTAssertEqual(
            WordKey.cardID(headword: "樹皮", reading: "じゅひ").uuidString,
            "59E7F28B-1CFA-52E3-B55F-7F6E746ACB44")
        XCTAssertNotEqual(
            WordKey.cardID(headword: "樹皮", reading: "じゅひ"),
            WordKey.cardID(headword: "樹皮", reading: "きかわ"))
        let card = Card(headword: "樹皮", reading: "じゅひ", entryID: 1, sightings: [], created: Date())
        XCTAssertEqual(card.id, WordKey.cardID(headword: "樹皮", reading: "じゅひ"))
    }
}
