import XCTest

@testable import YomidoriCore

final class AnswerDiffTests: XCTestCase {
    func testOneWrongKanaMarksOneKana() {
        XCTAssertEqual(
            AnswerDiff.of(typed: "そっちょく", answer: "そっちよく"),
            [.same("そっち"), .extra("ょ"), .missing("よ"), .same("く")])
    }

    func testAMissingAndAnExtraKana() {
        XCTAssertEqual(
            AnswerDiff.of(typed: "にきび", answer: "にきびい"), [.same("にきび"), .missing("い")])
        XCTAssertEqual(
            AnswerDiff.of(typed: "わがはいい", answer: "わがはい"), [.same("わがはい"), .extra("い")])
    }

    func testKatakanaAndSpacesAreNoSlip() {
        XCTAssertEqual(AnswerDiff.of(typed: "ウンザリ ", answer: "うんざり"), [.same("うんざり")])
    }

    func testNothingTypedIsAllMissing() {
        XCTAssertEqual(AnswerDiff.of(typed: "", answer: "ねこ"), [.missing("ねこ")])
    }
}
