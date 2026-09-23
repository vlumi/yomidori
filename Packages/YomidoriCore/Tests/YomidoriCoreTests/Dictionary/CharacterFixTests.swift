import XCTest

@testable import YomidoriCore
@testable import YomidoriDictionary

final class CharacterFixTests: XCTestCase {
    private struct Stub: WordDictionary {
        let words: [String]
        var common: Set<String> = []

        func entries(matching text: String) -> [DictionaryEntry] { [] }
        func pitchAccents(for headword: String, reading: String) -> [PitchAccent] { [] }
        func search(_ query: String, limit: Int) -> [DictionaryEntry] { [] }
        func entries(spelledLike form: String, anyCharacterAt index: Int, limit: Int)
            -> [DictionaryEntry]
        {
            let spelled = Array(form)
            return words.filter { word in
                let letters = Array(word)
                return word != form && letters.count == spelled.count
                    && letters.indices.allSatisfy { $0 == index || letters[$0] == spelled[$0] }
            }
            .sorted { common.contains($0) && !common.contains($1) }
            .enumerated().map { number, word in
                DictionaryEntry(
                    id: number, kanji: [word], readings: [], senses: [],
                    common: common.contains(word))
            }
        }
    }

    func testTheWordsSpelledLikeTheRestOfferTheirCharacterCommonFirst() {
        let dictionary = Stub(words: ["樹皮", "表皮", "外皮", "樹木"], common: ["表皮"])
        let fixes = CharacterFix.candidates(for: "街皮", at: 0, dictionary: dictionary)
        XCTAssertEqual(fixes.map(\.character), ["表", "樹", "外"])
        XCTAssertEqual(fixes.first?.entry.headword, "表皮")
        XCTAssertEqual(CharacterFix.candidates(for: "街皮", at: 5, dictionary: dictionary), [])
    }

    func testACutStemIsTriedAsItsDictionaryForm() {
        // 額い is 頷い misread; the stem's forms (額く, 額ぐ) find 頷く.
        let dictionary = Stub(words: ["頷く"])
        XCTAssertEqual(
            CharacterFix.candidates(for: "額い", at: 0, dictionary: dictionary).map(\.character),
            ["頷"])
    }

    func testTheBundledDictionaryAnswersTheSameQuestion() throws {
        let url = try XCTUnwrap(
            Bundle.module.url(
                forResource: "jmdict-fixture", withExtension: "sqlite", subdirectory: "Fixtures"))
        let jmdict = try JMdict(url: url)
        XCTAssertEqual(
            CharacterFix.candidates(for: "街皮", at: 0, dictionary: jmdict).map(\.character), ["樹"])
        XCTAssertEqual(jmdict.entries(spelledLike: "樹皮", anyCharacterAt: 0, limit: 5), [])
        XCTAssertEqual(
            jmdict.entries(spelledLike: "生_", anyCharacterAt: 1, limit: 5).map(\.headword), ["生地"])
    }
}
