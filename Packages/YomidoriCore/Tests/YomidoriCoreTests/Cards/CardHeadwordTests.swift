import XCTest

@testable import YomidoriCore

/// A card is headed by the word as the book spells it, in its dictionary form; the kana
/// are folded to hiragana and modern kana, the kanji left as printed.
final class CardHeadwordTests: XCTestCase {
    private let sense = DictionaryEntry.Sense(partsOfSpeech: ["n"], glosses: ["thing"])
    private let verb = DictionaryEntry.Sense(partsOfSpeech: ["v5m"], glosses: ["to read"])

    private func word(
        _ surface: String, reading: String, dictionaryForm: String? = nil, written: String? = nil,
        entry: DictionaryEntry
    ) -> FoundWord {
        let token = Token(
            surface: surface, reading: reading, range: surface.startIndex..<surface.endIndex,
            isWord: true, dictionaryForm: dictionaryForm, written: written)
        return FoundWord(tokens: [token], entries: [entry])
    }

    func testAWordInKanaIsAKanaCard() {
        let koto = DictionaryEntry(
            id: 1, kanji: ["事"], readings: ["こと"], senses: [sense], common: true)
        XCTAssertEqual(word("こと", reading: "こと", entry: koto).cardHeadword, "こと")
        XCTAssertEqual(word("コト", reading: "こと", entry: koto).cardHeadword, "こと")
        XCTAssertEqual(word("事", reading: "こと", entry: koto).cardHeadword, "事")
        XCTAssertNotEqual(
            word("こと", reading: "こと", entry: koto).wordKey,
            word("事", reading: "こと", entry: koto).wordKey)
    }

    func testALoanwordKeepsItsKatakana() {
        let tv = DictionaryEntry(
            id: 2, kanji: [], readings: ["テレビ"], senses: [sense], common: true)
        XCTAssertEqual(word("テレビ", reading: "てれび", entry: tv).cardHeadword, "テレビ")
    }

    func testOldKanjiStayAsPrinted() {
        let war = DictionaryEntry(
            id: 3, kanji: ["戦争"], readings: ["せんそう"], senses: [sense], common: true)
        XCTAssertEqual(word("戰爭", reading: "せんそう", entry: war).cardHeadword, "戰爭")
        let read = DictionaryEntry(
            id: 4, kanji: ["読む"], readings: ["よむ"], senses: [verb], common: true)
        XCTAssertEqual(word("讀ん", reading: "よん", entry: read).cardHeadword, "讀む")
        XCTAssertEqual(
            word("読ん", reading: "よん", dictionaryForm: "読む", entry: read).cardHeadword, "読む")
    }

    func testOldKanaAreFoldedToHiraganaAsWrittenToday() {
        let tadashi = DictionaryEntry(
            id: 5, kanji: ["但し"], readings: ["ただし"], senses: [sense], common: true)
        XCTAssertEqual(
            word("但し", reading: "ただし", written: "但シ", entry: tadashi).cardHeadword, "但し")
        let think = DictionaryEntry(
            id: 6, kanji: ["思う"], readings: ["おもう"], senses: [verb], common: true)
        XCTAssertEqual(
            word("思う", reading: "おもう", written: "思ふ", entry: think).cardHeadword, "思う")
    }

    func testASpellingTheEntryLacksTakesItsHeadword() {
        let war = DictionaryEntry(
            id: 3, kanji: ["戦争"], readings: ["せんそう"], senses: [sense], common: true)
        XCTAssertEqual(word("線争", reading: "せんそう", entry: war).cardHeadword, "戦争")
    }
}
