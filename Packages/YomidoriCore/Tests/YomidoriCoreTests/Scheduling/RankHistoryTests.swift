import XCTest

@testable import YomidoriCore

final class RankHistoryTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }
    /// Noon UTC on day 0.
    private let noon = Date(timeIntervalSince1970: 1_790_000_000 - 51_200 + 43_200)

    private func at(_ day: Int, hour: Double = 0) -> Date {
        noon.addingTimeInterval((Double(day) * 24 + hour) * 3600)
    }

    private func card(_ word: String, _ reading: String, created day: Int) -> Card {
        Card(headword: word, reading: reading, entryID: nil, sightings: [], created: at(day))
    }

    private func ranks(_ snapshot: RankSnapshot) -> [Rank: Int] {
        Dictionary(
            uniqueKeysWithValues: Rank.allCases.map { ($0, snapshot.count(of: $0)) }
        ).filter { $0.value > 0 }
    }

    /// Kept, started, answered twice, back to waiting, shelved: each shows on the day after.
    func testACardsMovesAndAnswersReplayDayByDay() {
        var bark = card("樹皮", "じゅひ", created: 0)
        bark.start(at: at(2))
        bark.answer(.reading, grade: .good, at: at(2, hour: 1))
        bark.answer(.meaning, grade: .good, at: at(2, hour: 1))
        // Seven days of stability take the chick's band, thirty the fledgling's.
        for day in [6, 10, 20] {
            bark.answer(.reading, grade: .good, at: at(day))
            bark.answer(.meaning, grade: .good, at: at(day))
        }
        bark.sendToWaiting(at: at(25))
        bark.shelve(at: at(30))
        let history = RankHistory.replay([bark], through: at(32), calendar: calendar)
        XCTAssertEqual(history.count, 32)
        XCTAssertEqual(history.first?.day, calendar.startOfDay(for: at(1)))
        XCTAssertEqual(ranks(history[0]), [.egg: 1])
        XCTAssertEqual(ranks(history[1]), [.egg: 1])
        XCTAssertEqual(ranks(history[2]), [.hatchling: 1])
        XCTAssertEqual(ranks(history[7]), [.chick: 1])
        XCTAssertEqual(ranks(history[20]), [.fledgling: 1])
        XCTAssertEqual(ranks(history[25]), [.egg: 1])
        XCTAssertEqual(ranks(history[31]), [.nest: 1])
        // The questions apart: a kana word's reading is not counted.
        var kana = card("ゆっくり", "ゆっくり", created: 0)
        kana.start(at: at(0, hour: 1))
        let both = RankHistory.replay([bark, kana], through: at(3), calendar: calendar)
        XCTAssertEqual(both[1].count(of: .hatchling, for: .reading), 0)
        XCTAssertEqual(both[1].count(of: .hatchling, for: .meaning), 1)
        XCTAssertEqual(both[2].count(of: .hatchling, for: .reading), 1)
        XCTAssertEqual(both[2].count(of: .hatchling, for: .meaning), 2)
    }

    /// A card from before moves were kept has none: it is read from where it stands now.
    func testACardWithoutMovesIsReadFromWhereItStands() {
        var reviewed = card("部屋", "へや", created: 0)
        reviewed.answer(.reading, grade: .good, at: at(3))
        reviewed = Card(
            id: reviewed.id, headword: reviewed.headword, reading: reviewed.reading, entryID: nil,
            sightings: [], created: reviewed.created, review: reviewed.review, log: reviewed.log,
            started: at(2))
        var waiting = card("円柱", "えんちゅう", created: 0)
        waiting.answer(.reading, grade: .good, at: at(3))
        waiting.answer(.reading, grade: .good, at: at(6))
        waiting = Card(
            id: waiting.id, headword: waiting.headword, reading: waiting.reading, entryID: nil,
            sightings: [], created: waiting.created, log: waiting.log)
        var shelved = card("山根", "やまね", created: 0)
        shelved = Card(
            id: shelved.id, headword: shelved.headword, reading: shelved.reading, entryID: nil,
            sightings: [], created: shelved.created, shelved: true)
        let history = RankHistory.replay(
            [reviewed, waiting, shelved], through: at(8), calendar: calendar)
        XCTAssertEqual(ranks(history[0]), [.egg: 2, .nest: 1])
        XCTAssertEqual(ranks(history[2]), [.hatchling: 1, .egg: 1, .nest: 1])
        XCTAssertEqual(ranks(history[3]), [.hatchling: 2, .nest: 1])
        // Sent back to waiting from its last answer on.
        XCTAssertEqual(ranks(history[6]), [.hatchling: 1, .egg: 1, .nest: 1])
        XCTAssertEqual(RankHistory.replay([], through: at(8), calendar: calendar), [])
    }
}
