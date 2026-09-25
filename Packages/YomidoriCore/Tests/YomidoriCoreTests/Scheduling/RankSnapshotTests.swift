import XCTest

@testable import YomidoriCore

final class RankSnapshotTests: XCTestCase {
    private var url: URL!

    override func setUp() {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapshots-\(UUID().uuidString).json")
    }

    private func cards() -> [Card] {
        var started = Card(
            headword: "樹皮", reading: "じゅひ", entryID: nil, sightings: [], created: Date())
        started.start(at: Date())
        let waiting = Card(
            headword: "部屋", reading: "へや", entryID: nil, sightings: [], created: Date())
        var shelved = Card(
            headword: "山根", reading: "やまね", entryID: nil, sightings: [], created: Date())
        shelved.shelve()
        return [started, waiting, shelved]
    }

    func testTheFirstLookOfADayIsKept() throws {
        let store = FileRankSnapshots(url: url)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        // Noon UTC, so an hour later is the same day wherever the test runs.
        let morning = Date(timeIntervalSince1970: 1_790_000_000 - 51_200 + 43_200)
        XCTAssertTrue(try store.take(of: cards(), at: morning, calendar: calendar))
        // Later the same day, with a card more: not taken.
        XCTAssertFalse(
            try store.take(
                of: cards() + [cards()[1]], at: morning.addingTimeInterval(3600),
                calendar: calendar))
        XCTAssertTrue(
            try store.take(of: cards(), at: morning.addingTimeInterval(86_400), calendar: calendar))
        let snapshots = FileRankSnapshots(url: url).snapshots()
        XCTAssertEqual(snapshots.count, 2)
        XCTAssertEqual(snapshots[0].day, calendar.startOfDay(for: morning))
        XCTAssertEqual(snapshots[0].count(of: .hatchling), 1)
        XCTAssertEqual(snapshots[0].count(of: .egg), 1)
        XCTAssertEqual(snapshots[0].count(of: .nest), 1)
        XCTAssertEqual(snapshots[0].count(of: .migrating), 0)
        XCTAssertLessThan(snapshots[0].day, snapshots[1].day)
    }
}
