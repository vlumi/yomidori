import XCTest

@testable import YomidoriCore

final class UsuallyKanaTests: XCTestCase {
    private func entry(_ headword: String, misc: [String] = [], common: Bool = true)
        -> DictionaryEntry
    {
        DictionaryEntry(
            id: headword.hashValue, kanji: [headword], readings: ["いる"],
            senses: [DictionaryEntry.Sense(partsOfSpeech: ["v1"], glosses: ["g"], misc: misc)],
            common: common)
    }

    func testARareWordUsuallyInKanaDoesNotGoFirst() {
        let entries = [entry("所"), entry("野老", misc: ["uk"], common: false)]
        XCTAssertEqual(entries.preferringKana(for: "ところ").map(\.headword), ["所", "野老"])
    }

    func testAWordInKanaPrefersTheEntriesUsuallyWrittenSo() {
        let entries = [entry("射る"), entry("入る"), entry("居る", misc: ["uk"])]
        XCTAssertEqual(entries.preferringKana(for: "いる").map(\.headword), ["居る", "射る", "入る"])
        // Written in kanji, the page has said which.
        XCTAssertEqual(entries.preferringKana(for: "射る").map(\.headword), ["射る", "入る", "居る"])
    }

    func testOnlyTheFirstSenseDecides() {
        let later = DictionaryEntry(
            id: 1, kanji: ["事"], readings: ["こと"],
            senses: [
                DictionaryEntry.Sense(partsOfSpeech: ["n"], glosses: ["thing"]),
                DictionaryEntry.Sense(partsOfSpeech: ["n"], glosses: ["fact"], misc: ["uk"]),
            ], common: true)
        XCTAssertFalse(later.isUsuallyKana)
        XCTAssertTrue(entry("居る", misc: ["uk", "arch"]).isUsuallyKana)
        // No kanji at all: kana is all it has.
        let kana = DictionaryEntry(
            id: 2, kanji: [], readings: ["いい"],
            senses: [DictionaryEntry.Sense(partsOfSpeech: ["adj-ix"], glosses: ["good"])],
            common: true)
        XCTAssertTrue(kana.isUsuallyKana)
    }
}
