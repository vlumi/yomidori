import XCTest

@testable import YomidoriCore

final class CardSortTests: XCTestCase {
    private func card(_ word: String, created: Date, modified: Date? = nil) -> Card {
        Card(
            headword: word, reading: word, entryID: nil, sightings: [], created: created,
            modified: modified)
    }

    func testByMonthNewestFirst() {
        let jan = Date(timeIntervalSince1970: 1_767_225_600)  // 2026-01-01
        let feb = Date(timeIntervalSince1970: 1_769_904_000)  // 2026-02-01
        let cards = [
            card("a", created: jan), card("b", created: feb.addingTimeInterval(86_400)),
            card("c", created: feb),
        ]
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let sections = CardSort.created.sections(cards, calendar: utc)
        XCTAssertEqual(sections.map(\.group), [.month(feb), .month(jan)])
        XCTAssertEqual(sections[0].cards.map(\.headword), ["b", "c"])
        // Modified: the change's month, not the making's.
        let changed = card("a", created: jan, modified: feb)
        XCTAssertEqual(
            CardSort.modified.sections([changed], calendar: utc).map(\.group), [.month(feb)])
    }

    func testByRankHighestFirstAndTheNestLast() {
        let now = Date()
        var started = card("s", created: now)
        started.start(at: now)
        var shelved = card("n", created: now)
        shelved.shelve()
        let waiting = card("w", created: now)
        let sections = CardSort.rank.sections([waiting, shelved, started])
        XCTAssertEqual(
            sections.map(\.group), [.rank(.hatchling), .rank(.egg), .rank(.nest)])
    }

    func testWordClassesFoldTheCodes() {
        XCTAssertEqual(WordClass.of(partsOfSpeech: ["n", "vs", "vi"]), [.noun, .verb])
        XCTAssertEqual(WordClass.of(partsOfSpeech: ["exp", "adj-i"]), [.expression, .adjective])
        XCTAssertEqual(WordClass.of(partsOfSpeech: ["adv", "adv-to"]), [.adverb])
        XCTAssertEqual(WordClass.of(partsOfSpeech: ["v5r", "vt"]), [.verb])
        XCTAssertEqual(WordClass.of(partsOfSpeech: ["n-suf"]), [.noun])
        XCTAssertEqual(WordClass.of(partsOfSpeech: ["pn"]), [.noun])
        XCTAssertEqual(WordClass.of(partsOfSpeech: ["int"]), [.other])
        XCTAssertEqual(WordClass.of(partsOfSpeech: ["n", "int"]), [.noun])
        XCTAssertEqual(WordClass.of(partsOfSpeech: []), [])
    }
}
