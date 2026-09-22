import XCTest

@testable import YomidoriCore

final class WordFinderTests: XCTestCase {
    private struct Stub: WordDictionary {
        let headwords: [String]

        var functionWords: [String] = []

        func entries(matching text: String) -> [DictionaryEntry] {
            guard headwords.contains(text) || functionWords.contains(text) else { return [] }
            let sense = DictionaryEntry.Sense(
                partsOfSpeech: functionWords.contains(text) ? ["aux-v"] : ["n"], glosses: ["g"])
            return [
                DictionaryEntry(
                    id: text.hashValue, kanji: [text], readings: [], senses: [sense], common: true)
            ]
        }
        func pitchAccents(for headword: String, reading: String) -> [PitchAccent] { [] }
        func search(_ query: String, limit: Int) -> [DictionaryEntry] { [] }
    }

    private let dictionary = Stub(headwords: ["蛍光灯", "蛍光", "灯", "照らす", "多重", "人格", "の"])

    private struct Cut {
        let surface: String
        let reading: String
        var isWord = true
    }

    private func tokens(_ text: String, _ cuts: [Cut]) -> [Token] {
        var index = text.startIndex
        return cuts.map { cut in
            let end = text.index(index, offsetBy: cut.surface.count)
            defer { index = end }
            return Token(
                surface: cut.surface, reading: cut.reading, range: index..<end, isWord: cut.isWord)
        }
    }

    func testTokensTheDictionaryKnowsAsOneWordJoin() {
        let words = WordFinder.words(
            in: tokens(
                "蛍光灯は",
                [
                    Cut(surface: "蛍光", reading: "けいこう"), Cut(surface: "灯", reading: "とう"),
                    Cut(surface: "は", reading: "は"),
                ]),
            dictionary: dictionary)
        XCTAssertEqual(words.map(\.surface), ["蛍光灯"])
        XCTAssertEqual(words.first?.reading, "けいこうとう")
        XCTAssertEqual(words.first?.entries.first?.headword, "蛍光灯")
    }

    func testAnInflectedStemFindsItsDictionaryForm() {
        let cut = tokens(
            "照らされていた",
            [
                Cut(surface: "照らさ", reading: "てらさ"), Cut(surface: "れ", reading: "れ"),
                Cut(surface: "て", reading: "て"), Cut(surface: "い", reading: "い"),
                Cut(surface: "た", reading: "た"),
            ])
        let words = WordFinder.words(in: cut, dictionary: dictionary)
        XCTAssertEqual(words.map(\.surface), ["照らさ"])
        XCTAssertEqual(words.first?.entries.first?.headword, "照らす")
    }

    func testEveryWordOfALongerSelectionIsListed() {
        let cut = tokens(
            "多重人格なんて",
            [
                Cut(surface: "多重", reading: "たじゅう"), Cut(surface: "人格", reading: "じんかく"),
                Cut(surface: "なんて", reading: "なんて"),
            ])
        let words = WordFinder.words(in: cut, dictionary: dictionary)
        XCTAssertEqual(words.map(\.surface), ["多重", "人格"])
        XCTAssertEqual(words.map(\.entries.count), [1, 1])
    }

    func testKanaFragmentsAndAuxiliariesAreSkipped() {
        var dictionary = dictionary
        dictionary.functionWords = ["ません"]
        let cut = tokens(
            "負えませんった",
            [
                Cut(surface: "負え", reading: "おえ"), Cut(surface: "ません", reading: "ません"),
                Cut(surface: "った", reading: "った"),
            ])
        XCTAssertEqual(WordFinder.words(in: cut, dictionary: dictionary).map(\.surface), ["負え"])
    }

    func testPunctuationAndLoneKanaAreSkipped() {
        let cut = tokens(
            "灯、の。",
            [
                Cut(surface: "灯", reading: "ひ"), Cut(surface: "、", reading: "", isWord: false),
                Cut(surface: "の", reading: "の"), Cut(surface: "。", reading: "", isWord: false),
            ])
        XCTAssertEqual(
            WordFinder.words(in: cut, dictionary: dictionary).map(\.surface), ["灯"])
    }

    func testWithoutADictionaryEveryWordTokenStands() {
        let cut = tokens(
            "蛍光灯", [Cut(surface: "蛍光", reading: "けいこう"), Cut(surface: "灯", reading: "とう")])
        XCTAssertEqual(WordFinder.words(in: cut, dictionary: nil).map(\.surface), ["蛍光", "灯"])
    }

    func testAWordAlignsToTheLineThatSpellsIt() {
        let line = tokens(
            "机の蛍光灯",
            [
                Cut(surface: "机", reading: "つくえ"), Cut(surface: "の", reading: "の"),
                Cut(surface: "蛍光", reading: "けいこう"), Cut(surface: "灯", reading: "とう"),
            ])
        let selection = tokens(
            "蛍光灯", [Cut(surface: "蛍光", reading: "けいこう"), Cut(surface: "灯", reading: "とう")])
        let word = WordFinder.words(in: selection, dictionary: dictionary)[0]
        let aligned = word.aligned(to: line)
        XCTAssertEqual(aligned?.tokens, Array(line[2...]))
        XCTAssertEqual(aligned?.entries, word.entries)
        XCTAssertNil(word.aligned(to: Array(line[..<2])))
    }
}
