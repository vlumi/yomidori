import XCTest

@testable import YomidoriCore

final class SyncMergeTests: XCTestCase {
    private let day: TimeInterval = 86_400
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func sighting(_ sentence: String, daysIn: Double) -> Sighting {
        Sighting(
            sentence: sentence, surface: "樹皮", offset: 0, source: nil,
            date: start.addingTimeInterval(daysIn * day))
    }

    private func started() -> Card {
        var card = Card(
            headword: "樹皮", reading: "じゅひ", entryID: 1, sightings: [sighting("樹皮。", daysIn: 0)],
            created: start)
        card.start(at: start)
        return card
    }

    func testTwoDevicesSightingsAnswersMeaningsAndCollectionsAllSurvive() {
        let base = started()
        var phone = base
        phone.add(sighting("樹皮の匂い。", daysIn: 1))
        phone.answer(.reading, grade: .good, at: start.addingTimeInterval(2 * day))
        phone.acceptedMeanings.append("bark")
        let book = UUID()
        phone.add(to: book)
        var mac = base
        mac.answer(.meaning, grade: .again, at: start.addingTimeInterval(3 * day))
        mac.acceptedMeanings.append("tree skin")
        let magazine = UUID()
        mac.add(to: magazine)
        let merged = phone.merged(with: mac)
        XCTAssertEqual(merged.sightings.map(\.sentence), ["樹皮。", "樹皮の匂い。"])
        XCTAssertEqual(merged.log.map(\.question), [.reading, .meaning])
        XCTAssertNotNil(merged.review)
        XCTAssertNotNil(merged.meaningReview)
        XCTAssertEqual(Set(merged.acceptedMeanings), ["bark", "tree skin"])
        XCTAssertEqual(Set(merged.collectionIDs), [book, magazine])
        XCTAssertEqual(merged, mac.merged(with: phone))
    }

    func testEachQuestionKeepsTheScheduleOfItsLaterAnswer() {
        var phone = started()
        var mac = phone
        phone.answer(.reading, grade: .again, at: start.addingTimeInterval(1 * day))
        mac.answer(.reading, grade: .good, at: start.addingTimeInterval(2 * day))
        let merged = phone.merged(with: mac)
        XCTAssertEqual(merged.review, mac.review)
        XCTAssertEqual(merged.log.count, 2)
    }

    func testACardSentBackToWaitingLaterStaysWaitingWithNoSchedule() {
        var phone = started()
        phone.answer(.reading, grade: .good, at: start.addingTimeInterval(1 * day))
        var mac = phone
        phone.answer(.meaning, grade: .good, at: start.addingTimeInterval(2 * day))
        mac.sendToWaiting()
        mac.add(sighting("また樹皮。", daysIn: 3))
        let merged = phone.merged(with: mac)
        XCTAssertTrue(merged.isWaiting)
        XCTAssertNil(merged.review)
        XCTAssertNil(merged.meaningReview)
        XCTAssertEqual(merged.log.count, 2)
    }

    func testTheLaterCollectionAndLookupWin() {
        let old = Collection(name: "羊", modified: start)
        var renamed = old
        renamed.name = "羊をめぐる冒険"
        renamed.modified = start.addingTimeInterval(day)
        XCTAssertEqual(old.merged(with: renamed).name, "羊をめぐる冒険")
        XCTAssertEqual(renamed.merged(with: old).name, "羊をめぐる冒険")
        let early = Lookup(headword: "樹皮", reading: "じゅひ", entryID: 1, date: start, source: .page)
        let late = Lookup(
            headword: "樹皮", reading: "じゅひ", entryID: 1, date: start.addingTimeInterval(day),
            source: .search)
        XCTAssertEqual(early.merged(with: late).source, .search)
    }
}
