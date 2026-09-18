import XCTest

@testable import YomidoriCore

final class SpreadTests: XCTestCase {
    func testPagesJoinAtTheSeamWithoutABreak() {
        let joined = Spread.join(["彼は薄暮の中で\n煙草に火を点けた。樹\n", "皮の匂いが部屋に\n漂っていた。\n"])
        XCTAssertEqual(joined, "彼は薄暮の中で\n煙草に火を点けた。樹皮の匂いが部屋に\n漂っていた。")
        XCTAssertEqual(
            SystemTokenizer().tokens(in: joined).first { $0.surface == "樹皮" }?.reading, "じゅひ")
    }

    func testEmptyPagesAreSkippedAndOffsetsCountCharacters() {
        XCTAssertEqual(Spread.join(["", "\n", "はい。"]), "はい。")
        let pages = ["樹\n", "", "皮の匂い"]
        XCTAssertEqual(Spread.offset(ofPage: 0, in: pages), 0)
        XCTAssertEqual(Spread.offset(ofPage: 2, in: pages), 1)
        let joined = Spread.join(pages)
        XCTAssertEqual(String(joined.dropFirst(Spread.offset(ofPage: 2, in: pages)).prefix(1)), "皮")
    }
}
