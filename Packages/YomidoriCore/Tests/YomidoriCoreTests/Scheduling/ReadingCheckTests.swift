import XCTest

@testable import YomidoriCore

final class ReadingCheckTests: XCTestCase {
    func testTheReadingInEitherScriptMatches() {
        XCTAssertTrue(ReadingCheck.matches(typed: "じゅひ", reading: "じゅひ"))
        XCTAssertTrue(ReadingCheck.matches(typed: "ジュヒ", reading: "じゅひ"))
        XCTAssertTrue(ReadingCheck.matches(typed: " じゅひ\n", reading: "じゅひ"))
    }

    func testAWrongOrEmptyAnswerDoesNot() {
        XCTAssertFalse(ReadingCheck.matches(typed: "じゅび", reading: "じゅひ"))
        XCTAssertFalse(ReadingCheck.matches(typed: "じゅ", reading: "じゅひ"))
        XCTAssertFalse(ReadingCheck.matches(typed: "", reading: "じゅひ"))
    }

    func testHalfWidthKanaAreReadAsFullWidth() {
        XCTAssertTrue(ReadingCheck.matches(typed: "ｼﾞｭﾋ", reading: "じゅひ"))
    }

    func testLongVowelsAreNotForgiven() {
        // おう and おお are different readings; a typed answer has to know which.
        XCTAssertFalse(ReadingCheck.matches(typed: "とうく", reading: "とおく"))
    }
}
