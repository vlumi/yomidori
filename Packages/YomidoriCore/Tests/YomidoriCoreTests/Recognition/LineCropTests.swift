import XCTest

@testable import YomidoriCore

final class LineCropTests: XCTestCase {
    private let image = CGSize(width: 3000, height: 4000)

    private func line(_ text: String, y: CGFloat) -> RecognizedLine {
        RecognizedLine(
            text: text, box: CGRect(x: 0.1, y: y, width: 0.8, height: 0.03), confidence: 1)
    }

    func testTheCropUnitesTheLinesOfTheSentenceAndPadsThem() {
        let lines = [
            line("彼は薄暮の中で煙草に火を点けた。樹皮の匂いが部", y: 0.90),
            line("屋に漂っていた。「はい」と彼女は言った。", y: 0.86),
            line("窓の外では雪が降っていた。", y: 0.82),
        ]
        let rect = LineCrop.rect(for: "樹皮の匂いが部屋に漂っていた。", lines: lines, imageSize: image)!
        // The two lines the sentence runs over, y-up boxes flipped to pixels, padded by 0.8 of a line's 120 px.
        XCTAssertEqual(rect.minX, 300 - 96, accuracy: 0.5)
        XCTAssertEqual(rect.minY, 4000 - 0.93 * 4000 - 96, accuracy: 0.5)
        XCTAssertEqual(rect.maxY, 4000 - 0.86 * 4000 + 96, accuracy: 0.5)
        XCTAssertEqual(rect.maxX, 2700 + 96, accuracy: 0.5)
    }

    func testNoMatchingLineMeansNoCrop() {
        let lines = [line("全然別の文章です。", y: 0.5)]
        XCTAssertNil(LineCrop.rect(for: "樹皮の匂いが部屋に漂っていた。", lines: lines, imageSize: image))
    }

    func testMatchingToleratesTheRecognizersSlips() {
        // The line has a misread character in it; six tenths as one run is enough.
        XCTAssertTrue(LineCrop.matches("樹皮の匂いが部屋に漂っていた", in: "街皮の匂いが部屋に漂っていた。"))
        XCTAssertTrue(LineCrop.matches("いた。", in: "樹皮の匂いが部屋に漂っていた。"))
        XCTAssertFalse(LineCrop.matches("。", in: "樹皮の匂いが部屋に漂っていた。"))
        XCTAssertFalse(LineCrop.matches("約125g", in: "樹皮の匂いが部屋に漂っていた。"))
    }
}
