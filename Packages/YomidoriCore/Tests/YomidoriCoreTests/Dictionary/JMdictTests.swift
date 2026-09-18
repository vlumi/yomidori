import XCTest
import YomidoriCore

@testable import YomidoriDictionary

/// The reader over a sliver of JMdict built by the same script as the real database.
final class JMdictTests: XCTestCase {
    private var dictionary: JMdict!

    override func setUpWithError() throws {
        let url = try XCTUnwrap(
            Bundle.module.url(
                forResource: "jmdict-fixture", withExtension: "sqlite", subdirectory: "Fixtures"))
        dictionary = try JMdict(url: url)
    }

    func testLooksUpByKanjiForm() {
        let entries = dictionary.entries(matching: "樹皮")
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.headword, "樹皮")
        XCTAssertEqual(entries.first?.readings, ["じゅひ"])
        XCTAssertEqual(entries.first?.senses.first?.glosses, ["bark (of a tree)"])
        XCTAssertEqual(entries.first?.senses.first?.partsOfSpeech, ["n"])
    }

    func testLooksUpByReadingAndByAnyKanjiForm() {
        XCTAssertEqual(dictionary.entries(matching: "うなずく").first?.headword, "頷く")
        XCTAssertEqual(dictionary.entries(matching: "肯く").first?.headword, "頷く")
        XCTAssertEqual(dictionary.entries(matching: "がい").first?.headword, "街")
    }

    func testSensesKeepTheirOrderAndInheritPartsOfSpeech() {
        let entry = dictionary.entries(matching: "生地").first
        XCTAssertEqual(entry?.senses.map(\.glosses.first), ["cloth", "dough", "inherent quality"])
        XCTAssertEqual(entry?.senses.map(\.partsOfSpeech), [["n"], ["n"], ["n"]])
        XCTAssertEqual(entry?.common, true)
        XCTAssertEqual(
            dictionary.entries(matching: "頷く").first?.senses.first?.partsOfSpeech, ["v5k", "vi"])
    }

    func testAMisreadWordIsNotAWord() {
        XCTAssertTrue(dictionary.entries(matching: "街皮").isEmpty)
        XCTAssertFalse(dictionary.entries(matching: "街").isEmpty)
    }

    func testMetaNamesTheSourceAndLicense() {
        XCTAssertEqual(dictionary.meta["source"], "JMdict_e (EDRDG)")
        XCTAssertEqual(dictionary.meta["created"], "2026-09-17")
        XCTAssertTrue(dictionary.meta["license"]?.contains("CC BY-SA 4.0") == true)
    }
}
