import XCTest

@testable import YomidoriCore

/// What every dictionary answers through the protocol's own code, whatever stands behind it.
final class WordDictionaryTests: XCTestCase {
    /// Words and estimates only: the least a dictionary must be.
    private struct WordsOnly: WordDictionary {
        func entries(matching text: String) -> [DictionaryEntry] {
            let sense = DictionaryEntry.Sense(partsOfSpeech: ["exp"], glosses: ["to have an idea"])
            switch text {
            case "見当がつく":
                return [
                    DictionaryEntry(
                        id: 1, kanji: [text], readings: ["けんとうがつく"], senses: [sense],
                        common: false)
                ]
            case "ばらばら":
                return [
                    DictionaryEntry(id: 2, kanji: [], readings: [], senses: [sense], common: false)
                ]
            default: return []
            }
        }
        func pitchAccents(for headword: String, reading: String) -> [PitchAccent] { [] }
        func estimatedPitch(for headword: String, reading: String) -> [PitchPhrase] {
            headword == "見当がつく" && reading == "けんとうがつく"
                ? [
                    PitchPhrase(reading: "けんとうが", downstep: 3),
                    PitchPhrase(reading: "つく", downstep: 1),
                ]
                : []
        }
        func search(_ query: String, limit: Int) -> [DictionaryEntry] { [] }
    }

    /// Words alone, the estimate left to the protocol.
    private struct NoEstimates: WordDictionary {
        func entries(matching text: String) -> [DictionaryEntry] { [] }
        func pitchAccents(for headword: String, reading: String) -> [PitchAccent] { [] }
        func search(_ query: String, limit: Int) -> [DictionaryEntry] { [] }
    }

    func testAnEntrysEstimateIsAskedByItsHeadwordAndFirstReading() throws {
        let dictionary = WordsOnly()
        let phrase = try XCTUnwrap(dictionary.entries(matching: "見当がつく").first)
        XCTAssertEqual(
            dictionary.estimatedPitch(of: phrase),
            [PitchPhrase(reading: "けんとうが", downstep: 3), PitchPhrase(reading: "つく", downstep: 1)])
        // No reading, nothing to ask by.
        let bare = try XCTUnwrap(dictionary.entries(matching: "ばらばら").first)
        XCTAssertEqual(dictionary.estimatedPitch(of: bare), [])
        XCTAssertEqual(NoEstimates().estimatedPitch(of: phrase), [])
    }

    func testADictionaryOfWordsAloneAnswersNothingAboutKanji() {
        let dictionary = NoEstimates()
        XCTAssertNil(dictionary.kanji("樹"))
        XCTAssertEqual(dictionary.entries(containing: "樹", limit: 10), [])
        XCTAssertEqual(dictionary.entries(spelledLike: "樹皮", anyCharacterAt: 0, limit: 10), [])
        XCTAssertEqual(dictionary.kanjiParts(), [])
        XCTAssertEqual(dictionary.kanji(withParts: ["木"], limit: 10), [])
        XCTAssertEqual(dictionary.parts(foundWith: ["木"]), [])
        XCTAssertEqual(dictionary.entries(forAny: ["樹皮", "樹"]), [])
    }
}
