import XCTest

@testable import YomidoriCore

final class TranscriptLinesTests: XCTestCase {
    private let transcript = "樹皮の匂いが\n\n部屋に漂っていた。\n彼女は頷いた。"

    func testLinesDropTheEmptyOnesAndKeepTheirStarts() {
        let lines = TranscriptLines(transcript)
        XCTAssertEqual(lines.lines, ["樹皮の匂いが", "部屋に漂っていた。", "彼女は頷いた。"])
        XCTAssertEqual(
            lines.starts.map { transcript.distance(from: transcript.startIndex, to: $0) },
            [0, 8, 18])
    }

    func testAnOffsetMapsToItsLineAndBack() {
        let lines = TranscriptLines(transcript)
        XCTAssertEqual(lines.lineIndex(atOffset: 0, in: transcript), 0)
        XCTAssertEqual(lines.lineIndex(atOffset: 10, in: transcript), 1)
        XCTAssertEqual(lines.lineIndex(atOffset: 18, in: transcript), 2)
        XCTAssertNil(lines.lineIndex(atOffset: 99, in: transcript))
        XCTAssertEqual(transcript[lines.index(inLine: 1, offset: 3, in: transcript)], "漂")
    }

    func testTheSentenceAroundATokenOnALine() {
        let lines = TranscriptLines(transcript)
        let tokens = SystemTokenizer().tokens(in: lines.lines[1])
        let token = tokens.first { $0.surface == "漂っ" }!
        let found = lines.sentence(around: token, onLine: 1, in: transcript)
        XCTAssertEqual(found.sentence.text, "樹皮の匂いが部屋に漂っていた。")
        XCTAssertEqual(found.sentence.offset(of: found.start, in: transcript), 9)
    }
}
