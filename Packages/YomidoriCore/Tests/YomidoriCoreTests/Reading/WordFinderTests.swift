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

    func testKanaPiecesJoinOnlyIntoAnExpression() {
        struct Kana: WordDictionary {
            func entries(matching text: String) -> [DictionaryEntry] {
                let pos: [String: String] = ["たが": "n", "かもしれない": "exp", "逢う": "v5u"]
                guard let tag = pos[text] else { return [] }
                return [
                    DictionaryEntry(
                        id: text.hashValue, kanji: [], readings: [text],
                        senses: [DictionaryEntry.Sense(partsOfSpeech: [tag], glosses: ["g"])],
                        common: true)
                ]
            }
            func pitchAccents(for headword: String, reading: String) -> [PitchAccent] { [] }
            func search(_ query: String, limit: Int) -> [DictionaryEntry] { [] }
        }
        let hoop = WordFinder.words(
            in: tokens("たが", [Cut(surface: "た", reading: "た"), Cut(surface: "が", reading: "が")]),
            dictionary: Kana())
        XCTAssertFalse(hoop.contains { $0.surface == "たが" })
        let maybe = WordFinder.words(
            in: tokens(
                "かもしれない",
                [
                    Cut(surface: "かも", reading: "かも"), Cut(surface: "しれ", reading: "しれ"),
                    Cut(surface: "ない", reading: "ない"),
                ]),
            dictionary: Kana())
        XCTAssertEqual(maybe.map(\.surface), ["かもしれない"])
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

    private struct Tagged: WordDictionary {
        /// Text to (reading, part of speech) of each entry spelled so.
        let words: [String: [(String, String)]]

        func entries(matching text: String) -> [DictionaryEntry] {
            (words[text] ?? []).enumerated().map { index, word in
                DictionaryEntry(
                    id: text.hashValue &+ index, kanji: [text], readings: [word.0],
                    senses: [DictionaryEntry.Sense(partsOfSpeech: [word.1], glosses: ["g"])],
                    common: true)
            }
        }
        func pitchAccents(for headword: String, reading: String) -> [PitchAccent] { [] }
        func search(_ query: String, limit: Int) -> [DictionaryEntry] { [] }
    }

    func testAVerbWithItsEndingCutOffIsTheVerbWhole() {
        let dictionary = Tagged(words: [
            "頼み": [("たのみ", "n")], "頼む": [("たのむ", "v5m")], "たい": [("たい", "n")],
            "認める": [("みとめる", "v1")],
        ])
        let wanted = tokens(
            "頼みたい", [Cut(surface: "頼み", reading: "たのみ"), Cut(surface: "たい", reading: "たい")])
        let words = WordFinder.words(in: wanted, dictionary: dictionary)
        XCTAssertEqual(words.map(\.surface), ["頼みたい"])
        XCTAssertEqual(words.first?.entries.first?.headword, "頼む")
        let admit = WordFinder.words(
            in: tokens("認めよう", [Cut(surface: "認めよう", reading: "みとめよう")]),
            dictionary: dictionary)
        XCTAssertEqual(admit.first?.entries.first?.headword, "認める")
    }

    func testTheTokenizersReadingPicksAmongEntriesSpelledAlike() {
        let dictionary = Tagged(words: ["本": [("もと", "n"), ("ほん", "n")]])
        let book = WordFinder.words(
            in: tokens("本", [Cut(surface: "本", reading: "ほん")]), dictionary: dictionary)
        XCTAssertEqual(book.first?.entries.first?.readings, ["ほん"])
    }
}
