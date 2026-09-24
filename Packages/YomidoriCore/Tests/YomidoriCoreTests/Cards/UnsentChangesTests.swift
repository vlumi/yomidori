import XCTest

@testable import YomidoriCore

final class UnsentChangesTests: XCTestCase {
    func testTheLatestChangeToARecordWins() {
        var unsent = UnsentChanges()
        XCTAssertTrue(unsent.isEmpty)
        unsent.note(.card, RecordChange(saved: ["a", "b"]))
        unsent.note(.card, RecordChange(deleted: ["a"]))
        unsent.note(.lookup, RecordChange(saved: ["他 た"]))
        unsent.noteHistoryCleared()
        XCTAssertEqual(
            unsent.saved,
            ["card-b", SyncName(.lookup, "他 た").recordName, SyncName.historyCleared.recordName])
        XCTAssertEqual(unsent.deleted, ["card-a"])
        unsent.note(.card, RecordChange(saved: ["a"]))
        XCTAssertTrue(unsent.saved.contains("card-a"))
        XCTAssertTrue(unsent.deleted.isEmpty)
    }

    func testItIsKeptInAFileGoneWhenEmpty() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("unsent-\(UUID().uuidString).json")
        XCTAssertEqual(UnsentChanges.read(from: url), UnsentChanges())
        var unsent = UnsentChanges()
        unsent.note(.collection, RecordChange(saved: ["c"]))
        try unsent.write(to: url)
        XCTAssertEqual(UnsentChanges.read(from: url), unsent)
        try UnsentChanges().write(to: url)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }
}
