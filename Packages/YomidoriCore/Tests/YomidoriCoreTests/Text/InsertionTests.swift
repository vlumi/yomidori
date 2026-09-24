import XCTest

@testable import YomidoriCore

final class InsertionTests: XCTestCase {
    func testAPieceGoesInAtTheCursorOrOverTheSelectionOrAtTheEnd() {
        XCTAssertEqual(
            Insertion.insert("樹", into: "皮", replacing: 0..<0), .init(text: "樹皮", cursor: 1))
        XCTAssertEqual(
            Insertion.insert("樹", into: "街皮", replacing: 0..<1), .init(text: "樹皮", cursor: 1))
        XCTAssertEqual(
            Insertion.insert("皮", into: "樹", replacing: nil), .init(text: "樹皮", cursor: 2))
        XCTAssertEqual(
            Insertion.insert("樹", into: "", replacing: 0..<0), .init(text: "樹", cursor: 1))
    }

    func testAnOutOfDateCursorIsHeldToTheText() {
        XCTAssertEqual(
            Insertion.insert("皮", into: "樹", replacing: 9..<12), .init(text: "樹皮", cursor: 2))
        XCTAssertEqual(
            Insertion.insert("樹", into: "皮", replacing: -3..<0), .init(text: "樹皮", cursor: 1))
    }

    func testNoCharacterIsSplit() {
        // 𠮷 is two UTF-16 units; a cursor between them goes to its edge.
        XCTAssertEqual(
            Insertion.insert("野", into: "𠮷家", replacing: 1..<1).text, "野𠮷家")
        XCTAssertEqual(
            Insertion.insert("野", into: "𠮷家", replacing: 1..<2), .init(text: "野家", cursor: 1))
        // か and a combining dakuten stay one character.
        XCTAssertEqual(
            Insertion.insert("X", into: "か\u{3099}き", replacing: 1..<1).text, "Xか\u{3099}き")
    }
}
