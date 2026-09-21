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

    func testPitchAccentsComeByHeadwordAndReading() {
        XCTAssertEqual(dictionary.pitchAccents(for: "樹皮", reading: "じゅひ").map(\.downstep), [1])
        XCTAssertEqual(dictionary.pitchAccents(for: "頷く", reading: "うなずく").map(\.downstep), [3, 0])
        XCTAssertEqual(dictionary.pitchAccents(for: "街", reading: "がい").map(\.downstep), [1])
        // Kanjium leaves the reading empty for a kana headword, and tags accents by part of speech.
        XCTAssertEqual(
            dictionary.pitchAccents(for: "かさかさ", reading: "かさかさ").map(\.downstep), [1, 0])
        XCTAssertTrue(dictionary.pitchAccents(for: "街皮", reading: "がいひ").isEmpty)
    }

    func testTypedSearchByKanjiKanaAndGloss() {
        XCTAssertEqual(dictionary.search("樹", limit: 10).map(\.headword), ["樹皮"])
        XCTAssertEqual(dictionary.search("うな", limit: 10).map(\.headword), ["頷く"])
        // Common words first among the prefix matches.
        XCTAssertEqual(
            Array(dictionary.search("生", limit: 10).map(\.headword).prefix(2)), ["生", "生地"])
        XCTAssertEqual(dictionary.search("nod", limit: 10).map(\.headword), ["頷く"])
        XCTAssertEqual(dictionary.search("raw fresh", limit: 10).map(\.headword), ["生"])
        XCTAssertTrue(dictionary.search("   ", limit: 10).isEmpty)
        XCTAssertTrue(dictionary.search("xyzzy", limit: 10).isEmpty)
    }

    func testAnEntryByHeadwordAndReadingAndForAToken() {
        XCTAssertEqual(dictionary.entry(headword: "街", reading: "がい")?.readings, ["まち", "がい"])
        XCTAssertNil(dictionary.entry(headword: "街", reading: "みち"))
        let stem = Token(
            surface: "頷い", reading: "うなずい", range: "頷い".startIndex..<"頷い".endIndex, isWord: true)
        XCTAssertEqual(dictionary.entries(for: stem).first?.headword, "頷く")
        let known = Token(
            surface: "頷い", reading: "うなずい", range: "頷い".startIndex..<"頷い".endIndex, isWord: true,
            dictionaryForm: "頷く")
        XCTAssertEqual(dictionary.entries(for: known).first?.headword, "頷く")
        XCTAssertEqual(
            dictionary.pitchAccent(of: dictionary.entries(matching: "樹皮")[0])?.downstep, 1)
    }

    func testAKanjiWithItsReadingsMeaningsFactsAndComponents() throws {
        let kanji = try XCTUnwrap(dictionary.kanji("樹"))
        XCTAssertEqual(kanji.onReadings, ["ジュ"])
        XCTAssertEqual(kanji.kunReadings, ["き", "う.える"])
        XCTAssertEqual(kanji.nanori, ["いつき", "たつ"])
        XCTAssertEqual(kanji.meanings, ["timber trees", "wood"])
        XCTAssertEqual(kanji.strokes, 16)
        XCTAssertEqual(kanji.grade, 6)
        XCTAssertEqual(kanji.jlpt, 1)
        XCTAssertEqual(kanji.frequency, 1150)
        XCTAssertEqual(kanji.components, ["木", "士", "冖", "寸", "豆"])
        XCTAssertEqual(dictionary.kanji("皮")?.nanori, [])
        XCTAssertNil(dictionary.kanji("木"))
    }

    func testWordsContainingAKanjiOrAWord() {
        XCTAssertEqual(dictionary.entries(containing: "樹", limit: 10).map(\.headword), ["樹皮"])
        XCTAssertEqual(dictionary.entries(containing: "生", limit: 10).map(\.headword), ["生地"])
        XCTAssertTrue(dictionary.entries(containing: "生地", limit: 10).isEmpty)
    }

    func testHomophonesShareTheReadingAndAreWrittenInKanji() {
        let town = dictionary.entries(matching: "街")[0]
        XCTAssertTrue(dictionary.homophones(of: town).isEmpty)
        let raw = dictionary.entries(matching: "生")[0]
        XCTAssertEqual(dictionary.homophones(of: raw).map(\.headword), [])
    }

    func testAMissingDatabaseFailsToOpen() {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent(
            "\(UUID().uuidString).sqlite")
        XCTAssertThrowsError(try JMdict(url: missing))
    }

    func testMetaNamesTheSourceAndLicense() {
        XCTAssertEqual(dictionary.meta["source"], "JMdict_e (EDRDG)")
        XCTAssertEqual(dictionary.meta["created"], "2026-09-17")
        XCTAssertTrue(dictionary.meta["license"]?.contains("CC BY-SA 4.0") == true)
        XCTAssertTrue(dictionary.meta["accents_attribution"]?.contains("Uros O.") == true)
        XCTAssertTrue(dictionary.meta["kanji_attribution"]?.contains("KANJIDIC") == true)
    }
}
