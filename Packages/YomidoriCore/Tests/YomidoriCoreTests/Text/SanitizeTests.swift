import XCTest

@testable import YomidoriCore

final class SanitizeTests: XCTestCase {
    func testControlAndBidiCharactersGoAndTextIsCut() {
        XCTAssertEqual(Sanitize.text("樹皮\u{202E}evil\u{0000}\u{FEFF}", limit: 100), "樹皮evil")
        XCTAssertEqual(Sanitize.text("一\n二\t三\u{2028}", limit: 100), "一二\t三")
        XCTAssertEqual(Sanitize.text("一\n二", limit: 100, keepsNewlines: true), "一\n二")
        // A letter under a thousand combining marks is one character, and is still cut.
        let zalgo = "a" + String(repeating: "\u{0301}", count: 1000) + "b"
        XCTAssertLessThanOrEqual(Sanitize.text(zalgo, limit: 10).unicodeScalars.count, 40)
        XCTAssertEqual(Sanitize.text("あいうえお", limit: 3), "あいう")
        XCTAssertEqual(Sanitize.text("吾輩は猫である", limit: 3), "吾輩は")
        // A family emoji is one character of several scalars; the joiner stays.
        XCTAssertEqual(Sanitize.text("👨\u{200D}👩\u{200D}👧", limit: 1).count, 1)
        XCTAssertEqual(
            Sanitize.texts(["book", "", "\u{202E}", "novel", "SF"], count: 2, limit: 10),
            ["book", "novel"])
    }
}
