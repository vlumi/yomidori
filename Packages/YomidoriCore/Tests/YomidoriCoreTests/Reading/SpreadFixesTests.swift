import XCTest

@testable import YomidoriCore

final class SpreadFixesTests: XCTestCase {
    func testAFixBelongsToThePageTextItWasMadeOn() {
        var fixes = SpreadFixes(texts: ["樹皮の匂い\n", "部屋に漂う"])
        // 匂 read as 句: fixed in the joined text, at offset 3.
        XCTAssertTrue(fixes.add(TextFix(offset: 3, length: 1, replacement: "匂")))
        XCTAssertEqual(fixes.fixedText, "樹皮の匂い部屋に漂う")
        XCTAssertTrue(fixes.hasFixes(onPage: 0))
        XCTAssertFalse(fixes.hasFixes(onPage: 1))

        // The other page taken again: its own fixes would go, the first page's stay.
        let retaken = fixes.matching(["樹皮の匂い\n", "窓の外"])
        XCTAssertEqual(retaken.fixedText, "樹皮の匂い窓の外")
        // The first page read by another recognizer: its fix stands aside, and comes back
        // with the text.
        let elsewhere = fixes.matching(["樹皮の句い", "部屋に漂う"])
        XCTAssertEqual(elsewhere.fixedText, "樹皮の句い部屋に漂う")
        XCTAssertTrue(elsewhere.isEmpty)
        XCTAssertEqual(elsewhere.matching(["樹皮の匂い", "部屋に漂う"]).fixedText, "樹皮の匂い部屋に漂う")
    }

    func testOffsetsAndRangesAreMappedThroughEachPagesOwnFixes() {
        var fixes = SpreadFixes(texts: ["ABCDE", "FGH"])
        // CD on the first page becomes XYZ; G on the second becomes nothing.
        fixes.add(TextFix(offset: 2, length: 2, replacement: "XYZ"))
        fixes.add(TextFix(offset: 7, length: 1, replacement: ""))
        XCTAssertEqual(fixes.fixedText, "ABXYZEFH")
        XCTAssertEqual(fixes.fixedOffset(ofPage: 1), 6)
        XCTAssertEqual(fixes.map(offset: 1), 1)
        XCTAssertEqual(fixes.map(offset: 3), 2)
        XCTAssertEqual(fixes.map(offset: 4), 5)
        XCTAssertEqual(fixes.map(offset: 5), 6)
        XCTAssertEqual(fixes.map(offset: 7), 7)
        XCTAssertEqual(fixes.map(offset: 8), 8)
        // BC: the range ends inside the replaced run, and takes the replacement whole.
        XCTAssertEqual(fixes.map(1..<3), 1..<5)
        XCTAssertEqual(fixes.map(2..<4), 2..<5)
        XCTAssertEqual(fixes.map(4..<6), 5..<7)
        XCTAssertEqual(fixes.map(6..<8), 7..<8)
        XCTAssertEqual(fixes.map(3..<3), 2..<2)
    }

    func testAFixOverTheSeamOrOffThePageIsNotTaken() {
        var fixes = SpreadFixes(texts: ["ABC", "", "DEF"])
        XCTAssertFalse(fixes.add(TextFix(offset: 2, length: 2, replacement: "XY")))
        XCTAssertFalse(fixes.add(TextFix(offset: 6, length: 1, replacement: "X")))
        XCTAssertTrue(fixes.isEmpty)
        // The empty page counts for nothing in the offsets.
        XCTAssertTrue(fixes.add(TextFix(offset: 3, length: 1, replacement: "X")))
        XCTAssertEqual(fixes.fixedText, "ABCXEF")
        XCTAssertTrue(fixes.hasFixes(onPage: 2))
        XCTAssertEqual(fixes.map(offset: 4), 4)
        XCTAssertEqual(SpreadFixes().map(offset: 3), 3)
    }

    func testFixesFollowOneAnotherOnAPage() {
        var fixes = SpreadFixes(texts: ["ABCD"])
        fixes.add(TextFix(offset: 1, length: 1, replacement: "XX"))
        // Made on "AXXCD": the D.
        fixes.add(TextFix(offset: 4, length: 1, replacement: "Y"))
        XCTAssertEqual(fixes.fixedText, "AXXCY")
        XCTAssertEqual(fixes.map(offset: 3), 4)
        XCTAssertEqual(fixes.map(0..<4), 0..<5)
    }
}
