import XCTest

@testable import YomidoriCore

final class VisionPageTests: XCTestCase {
    private let frame = CGRect(x: 0, y: 0, width: 1000, height: 1000)

    /// A column at the right of the page, 樹皮の匂い, one character per tenth of its height
    /// from the top down.
    private func column(boxes: Bool) -> RecognizedLine {
        let text = "樹皮の匂い"
        let character = { (index: Int) in
            CGRect(x: 0.8, y: 0.9 - Double(index + 1) * 0.1, width: 0.1, height: 0.1)
        }
        return RecognizedLine(
            text: text, box: CGRect(x: 0.8, y: 0.4, width: 0.1, height: 0.5), confidence: 1,
            characterBoxes: boxes ? (0..<5).map(character) : [])
    }

    func testTheTranscriptJoinsTheLinesAndKnowsWhereEachStarts() {
        let page = VisionPage(lines: [
            RecognizedLine(text: "樹皮の匂い", box: .zero, confidence: 1),
            RecognizedLine(text: "", box: .zero, confidence: 1),
            RecognizedLine(text: "がした。", box: .zero, confidence: 1),
        ])
        XCTAssertEqual(page.transcript, "樹皮の匂い\nがした。")
        XCTAssertEqual(page.starts, [0, 6])
        XCTAssertEqual(page.lines.count, 2)
    }

    func testATapFindsItsCharacterByBoxOrByItsShareOfTheColumn() {
        for boxes in [true, false] {
            let page = VisionPage(lines: [column(boxes: boxes)])
            // y 150 in the view is 0.85 up from the bottom: the first character, 樹.
            XCTAssertEqual(page.character(at: CGPoint(x: 850, y: 150), in: frame)?.character, 0)
            // y 350 is 0.65 up: the third, の; a tap at the column's edge counts.
            XCTAssertEqual(page.character(at: CGPoint(x: 805, y: 350), in: frame)?.character, 2)
            XCTAssertNil(page.character(at: CGPoint(x: 100, y: 100), in: frame))
        }
    }

    func testAWordsBoxIsTheUnionOfItsCharacters() {
        let line = column(boxes: true)
        let box = line.box(ofCharacters: 0..<2)
        XCTAssertEqual(box.minY, 0.7, accuracy: 0.0001)
        XCTAssertEqual(box.maxY, 0.9, accuracy: 0.0001)
        XCTAssertEqual(
            column(boxes: false).box(ofCharacters: 0..<2).minY, 0.7, accuracy: 0.0001)
        XCTAssertTrue(line.box(ofCharacters: 9..<12).isNull)
        // Boxes that do not match the text are dropped rather than trusted.
        XCTAssertEqual(
            RecognizedLine(text: "樹皮", box: .zero, confidence: 1, characterBoxes: [.zero])
                .characterBoxes, [])
    }

    func testFuriganaBesideAColumnIsDropped() {
        // 僅(わず)かに in a column at x 0.5…0.6, the furigana half size to its right.
        let cell = { (index: Int) in
            CGRect(x: 0.5, y: 0.9 - Double(index + 1) * 0.1, width: 0.1, height: 0.1)
        }
        let ruby = { (index: Int) in
            CGRect(x: 0.61, y: 0.9 - 0.1 - Double(index + 1) * 0.05, width: 0.05, height: 0.05)
        }
        let line = RecognizedLine(
            text: "僅わずかに", box: CGRect(x: 0.5, y: 0.5, width: 0.16, height: 0.4), confidence: 1,
            characterBoxes: [cell(0), ruby(0), ruby(1), cell(1), cell(2)])
        let read = line.droppingRuby()
        XCTAssertEqual(read.text, "僅かに")
        XCTAssertEqual(read.characterBoxes, [cell(0), cell(1), cell(2)])
    }

    func testFuriganaOnAShortLineIsDroppedToo() {
        let cell = { (index: Int) in
            CGRect(x: 0.5, y: 0.9 - Double(index + 1) * 0.1, width: 0.1, height: 0.1)
        }
        let ruby = { (index: Int) in
            CGRect(x: 0.61, y: 0.8 - Double(index + 1) * 0.05, width: 0.05, height: 0.05)
        }
        let line = RecognizedLine(
            text: "僅わずか", box: CGRect(x: 0.5, y: 0.6, width: 0.16, height: 0.3), confidence: 1,
            characterBoxes: [cell(0), ruby(0), ruby(1), cell(1)])
        XCTAssertEqual(line.droppingRuby().text, "僅か")
    }

    func testSmallKanaOfTheTextStay() {
        // っ is small and a little off the axis, but within the column.
        let cell = { (index: Int) in
            CGRect(x: 0.5, y: 0.9 - Double(index + 1) * 0.1, width: 0.1, height: 0.1)
        }
        let small = CGRect(x: 0.53, y: 0.63, width: 0.06, height: 0.06)
        let line = RecognizedLine(
            text: "待って", box: CGRect(x: 0.5, y: 0.5, width: 0.1, height: 0.4), confidence: 1,
            characterBoxes: [cell(0), small, cell(2)])
        XCTAssertEqual(line.droppingRuby().text, "待って")
        let bare = RecognizedLine(text: "僅わずか", box: .zero, confidence: 1)
        XCTAssertEqual(bare.droppingRuby(), bare)
    }
}
