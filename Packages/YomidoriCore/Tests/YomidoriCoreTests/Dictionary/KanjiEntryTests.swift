import XCTest

@testable import YomidoriCore

final class KanjiEntryTests: XCTestCase {
    func testTheKanjiOfATextEachOnceInOrder() {
        XCTAssertEqual(KanjiEntry.literals(in: "蛍光灯"), ["蛍", "光", "灯"])
        XCTAssertEqual(KanjiEntry.literals(in: "照らされていた"), ["照"])
        XCTAssertEqual(KanjiEntry.literals(in: "人々の々"), ["人", "々"])
        XCTAssertEqual(KanjiEntry.literals(in: "ひらがなカタカナABC"), [])
        XCTAssertEqual(KanjiEntry.literals(in: "木木林"), ["木", "林"])
    }
}
