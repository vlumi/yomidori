import XCTest

@testable import YomidoriCore

final class WordKeyTests: XCTestCase {
    func testACardsIDIsItsWordsForGood() {
        // Fixed: a change here changes every card's id, and sync loses track of them all.
        XCTAssertEqual(WordKey.of(headword: "樹皮", reading: "じゅひ"), "樹皮 じゅひ")
        XCTAssertEqual(
            WordKey.cardID(headword: "樹皮", reading: "じゅひ").uuidString,
            "59E7F28B-1CFA-52E3-B55F-7F6E746ACB44")
        XCTAssertNotEqual(
            WordKey.cardID(headword: "樹皮", reading: "じゅひ"),
            WordKey.cardID(headword: "樹皮", reading: "きかわ"))
        let card = Card(headword: "樹皮", reading: "じゅひ", entryID: 1, sightings: [], created: Date())
        XCTAssertEqual(card.id, WordKey.cardID(headword: "樹皮", reading: "じゅひ"))
    }

    /// Every screen that asks whether a word is kept derives the key the same way: an entry
    /// by its headword and first reading in hiragana; a word on the page by its entry when
    /// it has one, else its dictionary form, else its surface, read as the page reads it.
    func testEntriesAndWordsDeriveTheKeyACardIsKeptUnder() {
        let sense = DictionaryEntry.Sense(partsOfSpeech: ["n"], glosses: ["bark"])
        let entry = DictionaryEntry(
            id: 1, kanji: ["樹皮"], readings: ["ジュヒ"], senses: [sense], common: true)
        XCTAssertEqual(entry.hiraganaReading, "じゅひ")
        XCTAssertEqual(entry.wordKey, "樹皮 じゅひ")
        let text = "樹皮"
        let token = Token(
            surface: "樹皮", reading: "じゅひ", range: text.startIndex..<text.endIndex, isWord: true,
            dictionaryForm: "樹皮")
        let known = FoundWord(tokens: [token], entries: [entry])
        XCTAssertEqual(known.cardHeadword, "樹皮")
        XCTAssertEqual(known.wordKey, entry.wordKey)
        let unknown = FoundWord(tokens: [token], entries: [])
        XCTAssertEqual(unknown.cardHeadword, "樹皮")
        XCTAssertEqual(unknown.cardReading, "じゅひ")
        XCTAssertEqual(unknown.wordKey, "樹皮 じゅひ")
        XCTAssertEqual(
            Card(
                headword: known.cardHeadword, reading: known.cardReading, entryID: nil,
                sightings: [], created: Date()
            ).wordKey, known.wordKey)
    }
}
