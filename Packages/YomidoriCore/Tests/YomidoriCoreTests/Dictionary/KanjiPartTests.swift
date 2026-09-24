import XCTest

@testable import YomidoriCore
@testable import YomidoriDictionary

final class KanjiPartTests: XCTestCase {
    private func fixture() throws -> JMdict {
        let url = try XCTUnwrap(
            Bundle.module.url(
                forResource: "jmdict-fixture", withExtension: "sqlite", subdirectory: "Fixtures"))
        return try JMdict(url: url)
    }

    func testAStandInShowsAsItsRadicalAndASymbolHasItsStrokes() {
        let water = KanjiPart(component: "汁", strokes: 5)
        XCTAssertEqual(water.glyph, "氵")
        XCTAssertEqual(water.strokes, 3)
        XCTAssertEqual(water.component, "汁")
        XCTAssertEqual(KanjiPart(component: "ノ", strokes: nil).strokes, 1)
        XCTAssertEqual(KanjiPart(component: "木", strokes: 4).glyph, "木")
    }

    func testPartsGroupByStrokesUnknownLast() {
        let groups = KanjiPart.byStrokes([
            KanjiPart(component: "木", strokes: 4), KanjiPart(component: "?", strokes: nil),
            KanjiPart(component: "汁", strokes: nil), KanjiPart(component: "口", strokes: 3),
        ])
        XCTAssertEqual(groups.map(\.strokes), [3, 4, nil])
        XCTAssertEqual(groups[0].parts.map(\.glyph), ["氵", "口"])
    }

    func testTheDictionaryFindsKanjiByAllTheirPartsAndTheOnesStillPossible() throws {
        let jmdict = try fixture()
        XCTAssertEqual(
            Set(jmdict.kanjiParts().map(\.component)), ["木", "士", "冖", "寸", "豆", "皮", "行", "土"])
        XCTAssertEqual(jmdict.kanji(withParts: ["木", "寸"], limit: 10), ["樹"])
        XCTAssertEqual(jmdict.kanji(withParts: ["土"], limit: 10), ["街"])
        XCTAssertEqual(jmdict.kanji(withParts: ["木", "行"], limit: 10), [])
        XCTAssertEqual(jmdict.kanji(withParts: [], limit: 10), [])
        XCTAssertEqual(jmdict.parts(foundWith: ["寸"]), ["木", "士", "冖", "寸", "豆"])
        XCTAssertEqual(jmdict.parts(foundWith: ["木", "行"]), [])
    }
}
