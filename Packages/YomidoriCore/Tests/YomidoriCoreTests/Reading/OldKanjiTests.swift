import XCTest

@testable import YomidoriCore

final class OldKanjiTests: XCTestCase {
    func testOldFormsAreMadeModern() {
        XCTAssertEqual(OldKanji.modern("戰爭"), "戦争")
        XCTAssertEqual(OldKanji.modern("圖書館"), "図書館")
        XCTAssertEqual(OldKanji.modern("國語を學ぶ"), "国語を学ぶ")
        XCTAssertEqual(OldKanji.modern("鐵道"), "鉄道")
    }

    func testModernTextHasNothingToChange() {
        XCTAssertNil(OldKanji.modern("戦争"))
        XCTAssertNil(OldKanji.modern("ひらがな"))
        XCTAssertNil(OldKanji.modern(""))
    }

    func testTheTableHoldsTheJoyoTablesOldForms() {
        let known = [
            "國": "国", "學": "学", "氣": "気", "戰": "戦", "圖": "図", "澤": "沢", "發": "発",
            "會": "会", "樂": "楽", "來": "来", "體": "体", "廣": "広", "臺": "台", "藝": "芸",
            "辯": "弁", "辨": "弁", "豫": "予", "當": "当", "聲": "声", "讀": "読", "實": "実",
            "舊": "旧", "歸": "帰", "變": "変", "從": "従", "對": "対", "惡": "悪", "佛": "仏",
            "圓": "円", "傳": "伝", "價": "価", "區": "区", "嚴": "厳", "齒": "歯", "鹽": "塩",
        ]
        for (old, new) in known {
            XCTAssertEqual(OldKanji.modern(old), new, old)
        }
    }
}
