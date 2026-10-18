import XCTest

@testable import YomidoriCore

final class ConjugableReadingTests: XCTestCase {
    private struct Stub: WordDictionary {
        /// Spelling → (headword, reading).
        let words: [String: (String, String)]

        func entries(matching text: String) -> [DictionaryEntry] {
            guard let (headword, reading) = words[text] else { return [] }
            let sense = DictionaryEntry.Sense(partsOfSpeech: ["v5r"], glosses: ["g"])
            return [
                DictionaryEntry(
                    id: headword.hashValue, kanji: [headword, text], readings: [reading],
                    senses: [sense], common: true)
            ]
        }
        func pitchAccents(for headword: String, reading: String) -> [PitchAccent] { [] }
        func search(_ query: String, limit: Int) -> [DictionaryEntry] { [] }
    }

    private let dictionary = Stub(words: ["終う": ("仕舞う", "しまう"), "終る": ("終わる", "おわる")])

    func testThePagesReadingPicksAmongTheStemsVerbs() {
        let candidates = Deinflector.candidates(for: "終っ")
        XCTAssertEqual(
            dictionary.entries(conjugableAmong: candidates, reading: "おわっ").first?.headword,
            "終わる")
        XCTAssertEqual(
            dictionary.entries(conjugableAmong: candidates, reading: "しまっ").first?.headword,
            "仕舞う")
        // Without a reading, the rows' order as before.
        XCTAssertEqual(dictionary.entries(conjugableAmong: candidates).first?.headword, "仕舞う")
    }

    func testAPageWordReadSoIsThatVerb() throws {
        let tokens = SystemTokenizer().tokens(in: "戦争が終った。")
        let words = WordFinder.words(in: tokens, dictionary: dictionary)
        XCTAssertEqual(words.first { $0.surface == "終っ" }?.entries.first?.headword, "終わる")
    }
}
