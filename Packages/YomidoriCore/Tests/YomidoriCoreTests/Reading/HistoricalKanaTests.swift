import XCTest

@testable import YomidoriCore

final class HistoricalKanaTests: XCTestCase {
    func testPrewarKanaInsideAWordAreMadeModern() {
        XCTAssertEqual(HistoricalKana.modern("思ふ"), "思う")
        XCTAssertEqual(HistoricalKana.modern("言ひ"), "言い")
        XCTAssertEqual(HistoricalKana.modern("あはれ"), "あわれ")
        XCTAssertEqual(HistoricalKana.modern("ゐる"), "いる")
        XCTAssertEqual(HistoricalKana.modern("戦へ"), "戦え")
    }

    func testAWordsFirstKanaIsAsWritten() {
        XCTAssertNil(HistoricalKana.modern("はな"))
        XCTAssertNil(HistoricalKana.modern("ひと"))
        XCTAssertNil(HistoricalKana.modern("思う"))
    }

    func testAFullSizeTsuDoublesOnlyBeforeAKSTOrPSound() {
        XCTAssertEqual(HistoricalKana.modern("終つ", before: "た"), "終っ")
        XCTAssertEqual(HistoricalKana.modern("待つて"), "待って")
        XCTAssertNil(HistoricalKana.modern("待つ"))
        XCTAssertNil(HistoricalKana.modern("待つ", before: "の"))
    }
}

final class HistoricalKanaWordTests: XCTestCase {
    private struct Stub: WordDictionary {
        let words: [String: [String]]

        func entries(matching text: String) -> [DictionaryEntry] {
            guard let kinds = words[text] else { return [] }
            let sense = DictionaryEntry.Sense(partsOfSpeech: kinds, glosses: ["g"])
            return [
                DictionaryEntry(
                    id: text.hashValue, kanji: [text], readings: [], senses: [sense], common: true)
            ]
        }
        func pitchAccents(for headword: String, reading: String) -> [PitchAccent] { [] }
        func search(_ query: String, limit: Int) -> [DictionaryEntry] { [] }
    }

    private let dictionary = Stub(words: [
        "思う": ["v5u"], "終る": ["v5r"], "彼": ["n"], "庭": ["n"], "思ふ": [],
    ])

    private func tokens(_ text: String) -> [Token] { SystemTokenizer().tokens(in: text) }

    func testAWordInPrewarKanaIsFoundAndKeepsItsSpelling() throws {
        let cut = tokens("思ふ")
        let word = try XCTUnwrap(WordFinder.words(in: cut, dictionary: dictionary).first)
        XCTAssertEqual(word.surface, "思う")
        XCTAssertEqual(word.written, "思ふ")
        XCTAssertEqual(word.entries.first?.headword, "思う")
        XCTAssertEqual(WordFinder.pageForm(of: word, in: cut), "思ふ")
    }

    func testParticlesStayParticles() {
        let words = WordFinder.words(in: tokens("彼は庭へ"), dictionary: dictionary)
        XCTAssertEqual(words.map(\.surface), ["彼", "庭"])
        XCTAssertEqual(words.map(\.written), ["彼", "庭"])
    }
}
