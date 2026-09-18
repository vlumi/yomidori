import XCTest

@testable import YomidoriCore

final class SearchQueryTests: XCTestCase {
    func testKindOfQuery() {
        XCTAssertEqual(SearchQuery.kind(of: "樹皮"), .japanese)
        XCTAssertEqual(SearchQuery.kind(of: "じゅひ"), .japanese)
        XCTAssertEqual(SearchQuery.kind(of: "ジュヒ"), .japanese)
        XCTAssertEqual(SearchQuery.kind(of: "bark"), .gloss)
        XCTAssertEqual(SearchQuery.kind(of: "tree bark"), .gloss)
        XCTAssertEqual(SearchQuery.kind(of: "  "), .empty)
    }
}
