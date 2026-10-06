import XCTest

@testable import YomidoriCore

final class TileStitchTests: XCTestCase {
    /// A column at x 0.5…0.6, one character a tenth tall from the top.
    private func cell(_ index: Int) -> CGRect {
        CGRect(x: 0.5, y: 0.9 - Double(index + 1) * 0.1, width: 0.1, height: 0.1)
    }

    /// A glyph seen by the upper or the lower tile of a page cut in two at the middle.
    private func glyph(_ character: Character, _ box: CGRect, upper: Bool = true) -> TileGlyph {
        TileGlyph(character: character, box: box, tile: CGPoint(x: 0.5, y: upper ? 0.75 : 0.25))
    }

    func testTheTilesCharactersReplaceTheLinesAndASeamsEchoIsDropped() {
        // The whole page read 名 as 発 and 前 badly; the tiles saw 名前 right, and both saw
        // the は and the ま at their seam, the lower one reading the は as ほ.
        let line = RecognizedLine(
            text: "発前はまだ", box: CGRect(x: 0.5, y: 0.4, width: 0.1, height: 0.5), confidence: 1,
            characterBoxes: (0..<5).map(cell))
        let glyphs = [
            glyph("名", cell(0)), glyph("前", cell(1)), glyph("は", cell(2)),
            glyph("ほ", cell(2).offsetBy(dx: 0.002, dy: 0.01), upper: false),
            glyph("ま", cell(3)), glyph("ま", cell(3), upper: false),
            glyph("だ", cell(4), upper: false),
        ]
        let stitched = TileStitch.stitch([line], with: glyphs)
        XCTAssertEqual(stitched.map(\.text), ["名前はまだ"])
        XCTAssertEqual(stitched[0].characterBoxes.count, 5)
        XCTAssertEqual(stitched[0].box, line.box)
    }

    func testFuriganaBesideTheColumnAndFuriganaLinesGo() {
        let line = RecognizedLine(
            text: "僅かに", box: CGRect(x: 0.5, y: 0.6, width: 0.16, height: 0.3), confidence: 1,
            characterBoxes: [cell(0), cell(1), cell(2)])
        let ruby = { (index: Int) in
            CGRect(x: 0.61, y: 0.9 - 0.1 - Double(index + 1) * 0.05, width: 0.05, height: 0.05)
        }
        let rubyLine = RecognizedLine(
            text: "わずか", box: CGRect(x: 0.61, y: 0.7, width: 0.05, height: 0.15), confidence: 1,
            characterBoxes: [ruby(0), ruby(1), ruby(2)])
        let usual = TileStitch.usualSize(of: [line, rubyLine])
        XCTAssertEqual(usual, 0.1, accuracy: 0.001)
        let skeleton = TileStitch.droppingRubyLines([line, rubyLine], usual: usual)
        XCTAssertEqual(skeleton.map(\.text), ["僅かに"])
        let glyphs = [
            glyph("僅", cell(0)), glyph("わ", ruby(0)), glyph("ず", ruby(1)), glyph("か", cell(1)),
            glyph("に", cell(2)),
        ]
        XCTAssertEqual(TileStitch.stitch(skeleton, with: glyphs).map(\.text), ["僅かに"])
    }

    func testALineNoTileSawKeepsItsText() {
        let line = RecognizedLine(
            text: "猫", box: cell(0), confidence: 1, characterBoxes: [cell(0)])
        let elsewhere = glyph("犬", CGRect(x: 0.1, y: 0.1, width: 0.1, height: 0.1))
        XCTAssertEqual(TileStitch.stitch([line], with: [elsewhere]).map(\.text), ["猫"])
        XCTAssertEqual(TileStitch.stitch([line], with: []), [line])
    }

    func testARowReadsLeftToRight() {
        let row = RecognizedLine(
            text: "ab", box: CGRect(x: 0.1, y: 0.5, width: 0.2, height: 0.1), confidence: 1,
            characterBoxes: [
                CGRect(x: 0.1, y: 0.5, width: 0.1, height: 0.1),
                CGRect(x: 0.2, y: 0.5, width: 0.1, height: 0.1),
            ])
        let glyphs = [
            glyph("y", CGRect(x: 0.2, y: 0.5, width: 0.1, height: 0.1)),
            glyph("x", CGRect(x: 0.1, y: 0.5, width: 0.1, height: 0.1)),
        ]
        XCTAssertEqual(TileStitch.stitch([row], with: glyphs).map(\.text), ["xy"])
    }
}
