import XCTest

@testable import YomidoriCore

final class CardSearchTests: XCTestCase {
    private let bark = Card(
        headword: "樹皮", reading: "じゅひ", entryID: nil, sightings: [], created: Date())
    private let meanings = ["bark (of a tree)", "Rinde"]

    private func found(_ query: String) -> Bool {
        CardSearch.matches(bark, query, meanings: meanings)
    }

    func testKanaInEitherScriptFindsTheReading() {
        XCTAssertTrue(found("じゅ"))
        XCTAssertTrue(found("ジュヒ"))
        XCTAssertFalse(found("じゅう"))
    }

    func testKanjiFindsTheHeadword() {
        XCTAssertTrue(found("皮"))
        XCTAssertTrue(found("樹皮"))
        XCTAssertFalse(found("皮膚"))
    }

    func testAMeaningIsFoundCaseAndAccentsAside() {
        XCTAssertTrue(found("Bark"))
        XCTAssertTrue(found("of a tree"))
        XCTAssertTrue(found("rinde"))
        XCTAssertFalse(found("leaf"))
    }

    func testBlankFindsEverythingAndSpacesAreTrimmed() {
        XCTAssertTrue(found(""))
        XCTAssertTrue(found("   "))
        XCTAssertTrue(found(" bark "))
    }
}
