import XCTest

@testable import YomidoriCore

final class StudySettingsTests: XCTestCase {
    private let earlier = Date(timeIntervalSince1970: 1_000)
    private let later = Date(timeIntervalSince1970: 2_000)

    func testTheLaterChangeWinsAndATieKeepsThisOne() {
        let mine = StudySettings(
            retention: 0.9, lessonOrder: .oldest, lessonSize: 5, modified: earlier)
        let theirs = StudySettings(
            retention: 0.95, lessonOrder: .random, lessonSize: 8, modified: later)
        XCTAssertEqual(mine.merged(with: theirs), theirs)
        XCTAssertEqual(theirs.merged(with: mine), theirs)
        let tie = StudySettings(
            retention: 0.95, lessonOrder: .common, lessonSize: 3, modified: earlier)
        XCTAssertEqual(mine.merged(with: tie), mine)
        XCTAssertTrue(
            mine.sameValues(
                as: StudySettings(
                    retention: 0.9, lessonOrder: .oldest, lessonSize: 5, modified: later)))
        XCTAssertFalse(mine.sameValues(as: tie))
    }

    func testOnlyOfferedValuesAreTaken() {
        let fine = StudySettings(
            retention: 0.95, lessonOrder: .newest, lessonSize: 50, modified: earlier)
        XCTAssertEqual(fine.sanitized(), fine)
        XCTAssertNil(
            StudySettings(retention: 0.5, lessonOrder: .newest, lessonSize: 5, modified: earlier)
                .sanitized())
        XCTAssertNil(
            StudySettings(retention: 0.9, lessonOrder: .newest, lessonSize: 0, modified: earlier)
                .sanitized())
        XCTAssertNil(
            StudySettings(
                retention: 0.9, lessonOrder: .newest, lessonSize: 5,
                modified: Date().addingTimeInterval(10 * 86_400)
            ).sanitized())
        // A record from a build with an order this one has not: not read, not taken.
        let data = Data(
            #"{"retention":0.9,"lessonOrder":"backwards","lessonSize":5,"modified":"2026-01-01T00:00:00Z"}"#
                .utf8)
        XCTAssertNil(SyncPayload.intake(StudySettings.self, from: data))
    }

    func testTheStoreHoldsOneRecordAndReportsWhoChangedIt() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("settings-\(UUID().uuidString).json")
        let store = FileStudySettings(url: url)
        var reported: [(RecordChange, ChangeOrigin)] = []
        store.file.onChange = { reported.append(($0, $1)) }
        XCTAssertNil(store.settings())
        let mine = StudySettings(
            retention: 0.9, lessonOrder: .oldest, lessonSize: 5, modified: earlier)
        try store.update(mine)
        XCTAssertEqual(store.settings(), mine)
        XCTAssertEqual(reported.last?.0, RecordChange(saved: [StudySettings.key]))
        XCTAssertEqual(reported.last?.1, .local)
        // An older record from another device changes nothing; a newer one takes over.
        let older = StudySettings(
            retention: 0.95, lessonOrder: .random, lessonSize: 9,
            modified: Date(timeIntervalSince1970: 500))
        try store.applyRemote(older)
        XCTAssertEqual(store.settings(), mine)
        XCTAssertEqual(reported.count, 1)
        let newer = StudySettings(
            retention: 0.95, lessonOrder: .random, lessonSize: 9, modified: later)
        try store.applyRemote(newer)
        XCTAssertEqual(store.settings(), newer)
        XCTAssertEqual(reported.last?.1, .remote)
        XCTAssertEqual(FileStudySettings(url: url).settings(), newer)
        XCTAssertEqual(SyncName.settings.recordName, "settings-settings")
        XCTAssertEqual(SyncName(recordName: "settings-settings"), .settings)
    }
}
