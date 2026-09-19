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
}
