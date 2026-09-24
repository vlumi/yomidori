import XCTest

@testable import YomidoriCore

final class RecordFileTests: XCTestCase {
    private var directory: URL!
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUp() {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
    }

    func testAChangeNamesWhatWasSavedAndDeleted() {
        let change = RecordChange.between(["a1", "b1", "c1"], ["a1", "b2", "d1"]) {
            String($0.prefix(1))
        }
        XCTAssertEqual(change, RecordChange(saved: ["b", "d"], deleted: ["c"]))
    }

    func testLocalWritesAreReportedAsLocalAndRemoteOnesAsRemoteAndNothingForNoChange() throws {
        let store = FileCardStore(url: directory.appendingPathComponent("cards.json"))
        var reports: [(RecordChange, ChangeOrigin)] = []
        store.file.onChange = { reports.append(($0, $1)) }
        let card = try store.keep(
            Sighting(sentence: "樹皮。", surface: "樹皮", offset: 0, source: nil, date: start),
            headword: "樹皮", reading: "じゅひ", entryID: 1)
        try store.update(card)
        XCTAssertEqual(reports.count, 1)
        XCTAssertEqual(reports[0].0.saved, [card.id.uuidString])
        XCTAssertEqual(reports[0].1, .local)
        let other = Card(
            headword: "頷く", reading: "うなずく", entryID: nil, sightings: [], created: start)
        try store.applyRemote(saving: [other], deleting: [card.id])
        XCTAssertEqual(reports.count, 2)
        XCTAssertEqual(
            reports[1].0, RecordChange(saved: [other.id.uuidString], deleted: [card.id.uuidString]))
        XCTAssertEqual(reports[1].1, .remote)
        XCTAssertEqual(FileCardStore(url: store.url).cards().map(\.headword), ["頷く"])
    }

    func testACollectionIsStampedWhenChangedAndNotWhenSavedAsItWas() throws {
        var clock = start
        let store = FileCollectionStore(url: directory.appendingPathComponent("c.json")) { clock }
        var reports = 0
        store.file.onChange = { _, _ in reports += 1 }
        try store.save(Collection(name: "羊", created: start))
        clock = start.addingTimeInterval(60)
        var book = try XCTUnwrap(store.collections().first)
        try store.save(book)
        XCTAssertEqual(reports, 1)
        book.note = "村上春樹"
        try store.save(book)
        XCTAssertEqual(store.collections().first?.modified, clock)
        XCTAssertEqual(reports, 2)
    }

    func testAClearReachesEveryDeviceAndOnlyLaterLookupsSurviveIt() throws {
        var clock = start
        let phone = FileLookupHistory(url: directory.appendingPathComponent("phone.json")) { clock }
        let mac = FileLookupHistory(url: directory.appendingPathComponent("mac.json")) { clock }
        func lookup(_ word: String, _ minutes: Double) -> Lookup {
            Lookup(
                headword: word, reading: word, entryID: 1,
                date: start.addingTimeInterval(minutes * 60),
                source: .page)
        }
        try mac.record(lookup("樹皮", 1))
        try mac.record(lookup("頷く", 5))
        var cleared: Date?
        phone.onClear = { cleared = $0 }
        clock = start.addingTimeInterval(3 * 60)
        try phone.clear()
        XCTAssertEqual(cleared, clock)
        // The Mac, offline during the clear, hears of it and of nothing else.
        try mac.applyRemote(saving: [], deleting: [], clearedAt: cleared)
        XCTAssertEqual(mac.lookups().map(\.headword), ["頷く"])
        // A lookup from before the clear arriving late is dropped; a later one is kept.
        try phone.applyRemote(
            saving: [lookup("樹皮", 1), lookup("頷く", 5)], deleting: [], clearedAt: nil)
        XCTAssertEqual(phone.lookups().map(\.headword), ["頷く"])
        XCTAssertEqual(
            FileLookupHistory(url: directory.appendingPathComponent("phone.json")).clearedAt,
            cleared)
    }

    func testARecordThatDoesNotDecodeIsKeptAndWrittenBackNotLostWithTheRest() throws {
        let url = directory.appendingPathComponent("cards.json")
        let store = FileCardStore(url: url)
        try store.keep(
            Sighting(sentence: "樹皮。", surface: "樹皮", offset: 0, source: nil, date: start),
            headword: "樹皮", reading: "じゅひ", entryID: 1)
        // A card a newer build wrote, with a grade this one does not know.
        var elements = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [[String: Any]])
        var newer = elements[0]
        newer["id"] = UUID().uuidString
        newer["headword"] = "頷く"
        newer["log"] = [
            [
                "date": "2026-09-18T00:00:00Z", "question": "reading", "grade": "easy",
                "reconciled": false,
            ]
        ]
        elements.append(newer)
        try JSONSerialization.data(withJSONObject: elements).write(to: url)
        let reopened = FileCardStore(url: url)
        XCTAssertEqual(reopened.cards().map(\.headword), ["樹皮"])
        try reopened.keep(
            Sighting(sentence: "相槌を打つ。", surface: "相槌", offset: 0, source: nil, date: start),
            headword: "相槌", reading: "あいづち", entryID: 2)
        let written = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [[String: Any]])
        XCTAssertEqual(written.count, 3)
        XCTAssertTrue(written.contains { $0["headword"] as? String == "頷く" })
    }

    func testAFileThatIsNoListIsSetAsideNotWrittenOver() throws {
        let url = directory.appendingPathComponent("cards.json")
        try Data("not json at all".utf8).write(to: url)
        let store = FileCardStore(url: url)
        XCTAssertEqual(store.cards(), [])
        try store.keep(
            Sighting(sentence: "樹皮。", surface: "樹皮", offset: 0, source: nil, date: start),
            headword: "樹皮", reading: "じゅひ", entryID: 1)
        let aside = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasPrefix("cards.unreadable-") }
        XCTAssertEqual(aside.count, 1)
        XCTAssertEqual(
            try String(contentsOf: directory.appendingPathComponent(aside[0]), encoding: .utf8),
            "not json at all")
    }
}
