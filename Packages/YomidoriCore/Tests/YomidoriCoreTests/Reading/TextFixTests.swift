import XCTest

@testable import YomidoriCore

final class TextFixTests: XCTestCase {
    private let text = "街皮の匂いが\n部屋に漂っていた。"

    func testAFixReplacesItsRunAndLaterFixesCountFromTheFixedText() {
        let fixes = [
            TextFix(offset: 0, length: 1, replacement: "樹"),
            TextFix(offset: 7, length: 2, replacement: "部屋"),
        ]
        XCTAssertEqual(TextFix.apply(fixes, to: text), "樹皮の匂いが\n部屋に漂っていた。")
        // A misread split in two (言 and 舌 for 話) is one fix of two characters to one.
        XCTAssertEqual(
            TextFix.apply([TextFix(offset: 2, length: 2, replacement: "話")], to: "彼は言舌した"),
            "彼は話した")
        XCTAssertEqual(
            TextFix.apply([TextFix(offset: 99, length: 1, replacement: "x")], to: text), text)
    }

    func testOffsetsFollowTheFixes() {
        let fixes = [TextFix(offset: 2, length: 2, replacement: "話")]
        XCTAssertEqual(TextFix.map(offset: 1, through: fixes), 1)
        XCTAssertEqual(TextFix.map(offset: 3, through: fixes), 2)
        XCTAssertEqual(TextFix.map(offset: 4, through: fixes), 3)
        XCTAssertEqual(TextFix.map(offset: 5, through: []), 5)
    }
}
