import XCTest

@testable import YomidoriCore

/// An answer counts for the day it was given on where it was given, wherever the reader
/// looks from later.
final class ReviewEntryZoneTests: XCTestCase {
    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!
    private let helsinki = TimeZone(identifier: "Europe/Helsinki")!

    private func calendar(_ zone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar
    }

    /// 2026-11-16 23:30 in Tokyo, which is 16:30 the same day in Helsinki.
    private var lateInTokyo: Date {
        calendar(tokyo).date(
            from: DateComponents(year: 2026, month: 11, day: 16, hour: 23, minute: 30))!
    }

    private func card(answeredAt date: Date, in zone: TimeZone?) -> Card {
        var card = Card(
            headword: "樹皮", reading: "じゅひ", entryID: nil, sightings: [],
            created: date.addingTimeInterval(-86_400))
        card.start(at: card.created)
        if let zone {
            card.answer(.reading, grade: .good, at: date, in: zone)
        } else {
            card.answer(.reading, grade: .good, at: date, in: tokyo)
            card = Card(
                id: card.id, headword: card.headword, reading: card.reading, entryID: nil,
                sightings: [], created: card.created, review: card.review,
                log: card.log.map {
                    ReviewEntry(
                        date: $0.date, question: $0.question, grade: $0.grade,
                        reconciled: $0.reconciled, seconds: $0.seconds, zoneOffset: nil)
                }, started: card.started)
        }
        return card
    }

    func testTheDayIsTheOneWhereTheAnswerWasGiven() {
        let entry = ReviewEntry(
            date: lateInTokyo, question: .reading, grade: .good, reconciled: false, zone: tokyo)
        XCTAssertEqual(entry.zoneOffset, 9 * 3600)
        let seenFromHelsinki = calendar(helsinki)
        // Tokyo's 16th, as Helsinki's calendar starts that date.
        XCTAssertEqual(
            entry.day(in: seenFromHelsinki),
            seenFromHelsinki.date(from: DateComponents(year: 2026, month: 11, day: 16)))
        // The viewer's own day for an entry with no zone: still the 16th here, since 16:30.
        let blank = ReviewEntry(
            date: lateInTokyo, question: .reading, grade: .good, reconciled: false, seconds: 0,
            zoneOffset: nil)
        XCTAssertEqual(
            blank.day(in: seenFromHelsinki), seenFromHelsinki.startOfDay(for: lateInTokyo))
        // An answer at 01:00 in Helsinki is the 17th there and stays so in Tokyo, where it was 08:00.
        let earlyInHelsinki = lateInTokyo.addingTimeInterval(8.5 * 3600)
        let entry2 = ReviewEntry(
            date: earlyInHelsinki, question: .meaning, grade: .again, reconciled: false,
            zone: helsinki)
        XCTAssertEqual(entry2.zoneOffset, 2 * 3600)
        XCTAssertEqual(
            entry2.day(in: calendar(tokyo)),
            calendar(tokyo).date(from: DateComponents(year: 2026, month: 11, day: 17)))
    }

    func testTheTalliesAndStreaksFollowTheAnswersZone() {
        let stamped = card(answeredAt: lateInTokyo, in: tokyo)
        let seenFromHelsinki = calendar(helsinki)
        let days = Progress.tallies(
            of: [stamped], from: lateInTokyo.addingTimeInterval(-86_400),
            to: lateInTokyo.addingTimeInterval(86_400),
            calendar: seenFromHelsinki)
        let the16th = seenFromHelsinki.date(from: DateComponents(year: 2026, month: 11, day: 16))!
        XCTAssertEqual(days.first { $0.day == the16th }?.total, 1)
        XCTAssertEqual(Records.studiedDays(of: [stamped], calendar: seenFromHelsinki), [the16th])
        // Seen from Hawaii the same instant is the 16th at 04:30; the answer stays on the 16th.
        let hawaii = calendar(TimeZone(identifier: "Pacific/Honolulu")!)
        XCTAssertEqual(
            Records.studiedDays(of: [stamped], calendar: hawaii),
            [hawaii.date(from: DateComponents(year: 2026, month: 11, day: 16))!])
        // An answer at 09:00 Tokyo on the 17th is the 16th in Hawaii; stamped, it stays the 17th.
        let morning = card(answeredAt: lateInTokyo.addingTimeInterval(9.5 * 3600), in: tokyo)
        XCTAssertEqual(
            Records.studiedDays(of: [morning], calendar: hawaii),
            [hawaii.date(from: DateComponents(year: 2026, month: 11, day: 17))!])
        // Unstamped, it takes the viewer's day, the 16th in Hawaii.
        let blank = card(answeredAt: lateInTokyo.addingTimeInterval(9.5 * 3600), in: nil)
        XCTAssertEqual(
            Records.studiedDays(of: [blank], calendar: hawaii),
            [hawaii.date(from: DateComponents(year: 2026, month: 11, day: 16))!])
    }

    func testAStampedAndAnUnstampedCopyOfOneAnswerMergeAsOne() {
        let stamped = card(answeredAt: lateInTokyo, in: tokyo)
        var blank = stamped
        blank = Card(
            id: stamped.id, headword: stamped.headword, reading: stamped.reading, entryID: nil,
            sightings: [], created: stamped.created, review: stamped.review,
            log: stamped.log.map {
                ReviewEntry(
                    date: $0.date, question: $0.question, grade: $0.grade,
                    reconciled: $0.reconciled, seconds: $0.seconds, zoneOffset: nil)
            }, started: stamped.started)
        XCTAssertEqual(blank.merged(with: stamped).log.map(\.zoneOffset), [9 * 3600])
        XCTAssertEqual(stamped.merged(with: blank).log.map(\.zoneOffset), [9 * 3600])
        XCTAssertEqual(stamped.merged(with: blank).log.count, 1)
    }

    func testAnOldLogReadsWithoutZonesAndTheStoreStampsItOnce() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "cards-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let old = """
            [{"id":"\(UUID().uuidString)","headword":"樹皮","reading":"じゅひ","entryID":1,
              "created":"2026-11-15T00:00:00Z","started":"2026-11-15T00:00:00Z","sightings":[],
              "log":[{"date":"2026-11-16T14:30:00Z","question":0,"grade":"good",
                      "reconciled":false,"seconds":5}]}]
            """
        try old.write(to: url, atomically: true, encoding: .utf8)
        let store = FileCardStore(url: url)
        XCTAssertEqual(store.cards()[0].log[0].zoneOffset, nil)
        XCTAssertEqual(try store.stampZones(tokyo), 1)
        XCTAssertEqual(try store.stampZones(tokyo), 0)
        let reopened = FileCardStore(url: url).cards()[0].log[0]
        XCTAssertEqual(reopened.zoneOffset, 9 * 3600)
        XCTAssertEqual(reopened.seconds, 5)
        XCTAssertTrue(try String(contentsOf: url, encoding: .utf8).contains("\"zone\" : 32400"))
    }
}
