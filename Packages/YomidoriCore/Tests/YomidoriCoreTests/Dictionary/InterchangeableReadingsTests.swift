import XCTest

@testable import YomidoriCore

final class InterchangeableReadingsTests: XCTestCase {
    private struct Stub: WordDictionary {
        private func entry(_ id: Int, _ kanji: String, _ reading: String, _ glosses: [String])
            -> DictionaryEntry
        {
            DictionaryEntry(
                id: id, kanji: [kanji], readings: [reading],
                senses: [DictionaryEntry.Sense(partsOfSpeech: ["v5k"], glosses: glosses)],
                common: true)
        }

        func entries(matching text: String) -> [DictionaryEntry] {
            switch text {
            case "吐く":
                return [
                    entry(1, "吐く", "はく", ["to vomit", "to breathe out"]),
                    entry(2, "吐く", "つく", ["to breathe out", "to tell (a lie)"]),
                ]
            case "生地":
                return [
                    entry(3, "生地", "きじ", ["cloth", "dough"]),
                    entry(4, "生地", "せいち", ["birthplace"]),
                ]
            default: return []
            }
        }
        func pitchAccents(for headword: String, reading: String) -> [PitchAccent] { [] }
        func search(_ query: String, limit: Int) -> [DictionaryEntry] { [] }
    }

    func testAnotherReadingForTheSameThingIsInterchangeable() {
        XCTAssertEqual(Stub().interchangeableReadings(of: "吐く", reading: "はく"), ["つく"])
        XCTAssertEqual(Stub().interchangeableReadings(of: "吐く", reading: "ツク"), ["はく"])
    }

    func testAReadingThatMeansSomethingElseIsNot() {
        XCTAssertEqual(Stub().interchangeableReadings(of: "生地", reading: "きじ"), [])
        XCTAssertEqual(Stub().interchangeableReadings(of: "生地", reading: "ちぢ"), [])
        XCTAssertEqual(Stub().interchangeableReadings(of: "無い", reading: "ない"), [])
    }

    func testAReadingQuestionAcceptsAnyOfSeveral() {
        XCTAssertTrue(ReadingCheck.matches(typed: "はく", readings: ["つく", "はく"]))
        XCTAssertTrue(ReadingCheck.matches(typed: "ツク", readings: ["つく", "はく"]))
        XCTAssertFalse(ReadingCheck.matches(typed: "ふく", readings: ["つく", "はく"]))
        XCTAssertFalse(ReadingCheck.matches(typed: "", readings: ["つく"]))
    }
}
