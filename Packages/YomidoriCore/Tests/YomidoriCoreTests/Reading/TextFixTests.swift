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

    func testASelectionFindsItsLineAfterAFixThatChangedTheLength() {
        let page = "彼は言舌した。\n窓の外では雪が降っていた。"
        let fixes = [TextFix(offset: 2, length: 2, replacement: "話")]
        let fixed = TextFix.apply(fixes, to: page)
        let lines = TranscriptLines(fixed)
        XCTAssertEqual(
            lines.lineIndex(
                ofSelection: page.range(of: "雪"), in: page, pageOffset: 0, transcript: fixed,
                fixes: fixes),
            1)
    }

    func testATokensOffsetsAndTheTokensOverARange() {
        let fixed = "前の文。\n樹皮の匂いがした。"
        let lines = TranscriptLines(fixed)
        let tokens = SystemTokenizer().tokens(in: lines.lines[1])
        let bark = tokens.first { $0.surface == "樹皮" }!
        let smell = tokens.first { $0.surface == "匂い" }!
        let offsets = lines.offsets(of: smell, onLine: 1, in: fixed)
        XCTAssertEqual(offsets.inLine, 3)
        XCTAssertEqual(offsets.inTranscript, 8)
        XCTAssertEqual(
            WordFinder.tokens(tokens, overlapping: 0..<2, in: lines.lines[1]).map(\.surface), ["樹皮"]
        )
        XCTAssertEqual(
            WordFinder.tokens(tokens, overlapping: 1..<4, in: lines.lines[1]),
            [bark, tokens[1], smell])
    }
}
