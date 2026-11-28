import XCTest

@testable import YomidoriCore

final class EraseTests: XCTestCase {
    private var directory: URL!
    private var stores: Erase.Stores!
    private let day = Date(timeIntervalSince1970: 1_790_000_000)

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "erase-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        stores = Erase.Stores(
            mark: FileEraseMark(url: directory.appendingPathComponent("erased.json")),
            cards: FileCardStore(url: directory.appendingPathComponent("cards.json")),
            collections: FileCollectionStore(
                url: directory.appendingPathComponent("collections.json")),
            lookups: FileLookupHistory(url: directory.appendingPathComponent("lookups.json")))
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
    }

    /// A card, a collection and a lookup, and a history cleared before the lookup.
    private func fill() throws {
        try stores.collections.save(Collection(name: "羅生門", note: ""))
        try stores.cards.keep(
            Sighting(sentence: "樹皮の匂い。", surface: "樹皮", offset: 0, source: nil, date: day),
            headword: "樹皮", reading: "じゅひ", entryID: nil)
        try stores.lookups.clear()
        try stores.lookups.record(
            Lookup(headword: "頷く", reading: "うなずく", entryID: 2, date: day, source: .page))
    }

    private func counts() -> [Int] {
        [
            stores.cards.cards().count, stores.collections.collections().count,
            stores.lookups.lookups().count,
        ]
    }

    func testAnEraseEmptiesEveryStoreAsThisDevicesChangeAndMarksTheDate() throws {
        try fill()
        XCTAssertEqual(counts(), [1, 1, 1])
        XCTAssertNotNil(stores.lookups.clearedAt)
        var reported: [(RecordChange, ChangeOrigin)] = []
        stores.cards.file.onChange = { reported.append(($0, $1)) }
        stores.collections.file.onChange = { reported.append(($0, $1)) }
        stores.lookups.file.onChange = { reported.append(($0, $1)) }
        try Erase.everything(stores, at: day.addingTimeInterval(0.7))
        XCTAssertEqual(counts(), [0, 0, 0])
        XCTAssertNil(stores.lookups.clearedAt)
        // To the second, as the records carry it.
        XCTAssertEqual(stores.mark.date, day)
        XCTAssertEqual(reported.map { $0.0.deleted.count }, [1, 1, 1])
        XCTAssertTrue(reported.allSatisfy { $0.1 == .local })
    }

    func testAnotherDevicesEraseWipesAsARemoteChangeAndAnOlderOneDoesNothing() throws {
        try fill()
        var origins: [ChangeOrigin] = []
        stores.cards.file.onChange = { origins.append($1) }
        XCTAssertTrue(try Erase.applyRemote(stores, at: day))
        XCTAssertEqual(counts(), [0, 0, 0])
        XCTAssertEqual(origins, [.remote])
        XCTAssertEqual(stores.mark.date, day)
        try fill()
        XCTAssertFalse(try Erase.applyRemote(stores, at: day.addingTimeInterval(-1)))
        XCTAssertFalse(try Erase.applyRemote(stores, at: day.addingTimeInterval(0.9)))
        XCTAssertEqual(counts(), [1, 1, 1])
        XCTAssertTrue(try Erase.applyRemote(stores, at: day.addingTimeInterval(1)))
        XCTAssertEqual(counts(), [0, 0, 0])
    }

    func testARecordIsStaleBeforeTheMarkAndAheadPastIt() {
        let later = day.addingTimeInterval(60)
        XCTAssertFalse(Erase.isStale(era: nil, mark: nil))
        XCTAssertFalse(Erase.isAhead(era: nil, mark: nil))
        // Sent before any erase, or by a build that kept none, against an erase here.
        XCTAssertTrue(Erase.isStale(era: nil, mark: day))
        XCTAssertTrue(Erase.isStale(era: day, mark: later))
        XCTAssertFalse(Erase.isStale(era: day, mark: day))
        // From past an erase this device has not fetched yet.
        XCTAssertTrue(Erase.isAhead(era: day, mark: nil))
        XCTAssertTrue(Erase.isAhead(era: later, mark: day))
        XCTAssertFalse(Erase.isAhead(era: day, mark: day))
    }
}
