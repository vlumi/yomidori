import XCTest

@testable import YomidoriCore

final class BackupTests: XCTestCase {
    private let day = Date(timeIntervalSince1970: 1_790_000_000)

    private func card(_ word: String, _ reading: String, sentence: String, id: UUID? = nil) -> Card
    {
        Card(
            id: id, headword: word, reading: reading, entryID: nil,
            sightings: [
                Sighting(sentence: sentence, surface: word, offset: 0, source: nil, date: day)
            ],
            created: day)
    }

    func testABackupComesBackAsItWent() throws {
        let story = Collection(name: "羅生門", note: "芥川")
        var bark = card("樹皮", "じゅひ", sentence: "樹皮の匂い。")
        bark.add(to: story.id)
        bark.start(at: day)
        bark.answer(.reading, grade: .good, at: day, seconds: 9)
        let backup = Backup(
            created: day, cards: [bark], collections: [story],
            lookups: [
                Lookup(headword: "樹皮", reading: "じゅひ", entryID: 1, date: day, source: .page)
            ])
        let back = try Backup.decoded(from: backup.encoded())
        XCTAssertEqual(back.cards, [bark])
        XCTAssertEqual(back.collections.map(\.name), ["羅生門"])
        XCTAssertEqual(back.lookups.map(\.headword), ["樹皮"])
        XCTAssertEqual(back.created, day)
    }

    func testTheCardsFileAloneIsABackupAndABadRecordIsLeftOut() throws {
        let cards = [card("樹皮", "じゅひ", sentence: "樹皮の匂い。")]
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var list = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoder.encode(cards)) as? [Any])
        list.append(["headword": "壊れた"])
        let back = try Backup.decoded(from: JSONSerialization.data(withJSONObject: list))
        XCTAssertEqual(back.cards, cards)
        XCTAssertTrue(back.collections.isEmpty)
        XCTAssertThrowsError(try Backup.decoded(from: Data("{\"notes\": 1}".utf8)))
        XCTAssertThrowsError(try Backup.decoded(from: Data("nonsense".utf8)))
    }

    func testRestoringAddsAndJoinsAndTakesNothingAway() {
        let here = [
            card("樹皮", "じゅひ", sentence: "樹皮の匂い。"), card("部屋", "へや", sentence: "部屋に入る。"),
        ]
        // The same word under an id from before ids were the word's, with another sentence.
        let old = card("樹皮", "じゅひ", sentence: "樹皮が剥げた。", id: UUID())
        let new = card("円柱", "えんちゅう", sentence: "大きな円柱。")
        let shelf = Collection(name: "本")
        let backup = Backup(
            created: day, cards: [old, new, new], collections: [shelf],
            lookups: [
                Lookup(
                    headword: "古い", reading: "ふるい", entryID: 1,
                    date: day.addingTimeInterval(-86_400), source: .search),
                Lookup(
                    headword: "新しい", reading: "あたらしい", entryID: 2,
                    date: day.addingTimeInterval(60), source: .search),
            ])
        let restored = backup.restored(
            onto: here, collections: [], lookups: [], clearedAt: day, lookupLimit: 500)
        XCTAssertEqual(restored.cards.map(\.headword), ["樹皮", "部屋", "円柱"])
        XCTAssertEqual(restored.cards[0].id, here[0].id)
        XCTAssertEqual(
            Set(restored.cards[0].sightings.map(\.sentence)), ["樹皮の匂い。", "樹皮が剥げた。"])
        XCTAssertEqual(restored.cards[2].id, WordKey.cardID(headword: "円柱", reading: "えんちゅう"))
        XCTAssertEqual(restored.addedCards, 1)
        XCTAssertEqual(restored.joinedCards, 1)
        XCTAssertEqual(restored.collections.map(\.name), ["本"])
        XCTAssertEqual(restored.addedCollections, 1)
        // The lookup from before the history was cleared stays gone.
        XCTAssertEqual(restored.lookups.map(\.headword), ["新しい"])
        // Restoring the same file again changes nothing.
        let again = backup.restored(
            onto: restored.cards, collections: restored.collections, lookups: restored.lookups,
            clearedAt: day, lookupLimit: 500)
        XCTAssertEqual(again.cards, restored.cards)
        XCTAssertEqual(again.addedCards, 0)
        XCTAssertEqual(again.joinedCards, 0)
        XCTAssertEqual(again.addedCollections, 0)
    }

    /// Into the stores themselves: each is merged inside its own write, so whatever the
    /// store holds when the write begins is kept, and nothing is reported as deleted for
    /// sync to send on.
    func testARestoreIntoTheStoresWritesEachOnceAndDeletesNothing() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("restore-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let cards = FileCardStore(url: folder.appendingPathComponent("cards.json"))
        let collections = FileCollectionStore(
            url: folder.appendingPathComponent("collections.json"))
        let lookups = FileLookupHistory(url: folder.appendingPathComponent("lookups.json"))

        let shelf = Collection(name: "本")
        let bark = card("樹皮", "じゅひ", sentence: "樹皮の匂い。")
        let backup = Backup(
            created: day,
            cards: [
                card("樹皮", "じゅひ", sentence: "樹皮が剥げた。"), card("円柱", "えんちゅう", sentence: "大きな円柱。"),
            ],
            collections: [shelf],
            lookups: [
                Lookup(headword: "円柱", reading: "えんちゅう", entryID: 2, date: day, source: .page)
            ])

        // What the stores hold, the backup knows nothing of.
        try cards.replaceAll { _ in [bark, self.card("部屋", "へや", sentence: "部屋に入る。")] }
        try collections.save(Collection(name: "雑誌"))
        try lookups.record(
            Lookup(
                headword: "部屋", reading: "へや", entryID: 1, date: day.addingTimeInterval(60),
                source: .search))

        var reports: [(RecordChange, ChangeOrigin)] = []
        cards.file.onChange = { reports.append(($0, $1)) }
        collections.file.onChange = { reports.append(($0, $1)) }
        lookups.file.onChange = { reports.append(($0, $1)) }

        let restored = try backup.restore(cards: cards, collections: collections, lookups: lookups)
        XCTAssertEqual(restored.addedCards, 1)
        XCTAssertEqual(restored.joinedCards, 1)
        XCTAssertEqual(restored.addedCollections, 1)
        XCTAssertEqual(cards.cards().map(\.headword), ["樹皮", "部屋", "円柱"])
        XCTAssertEqual(
            cards.cards()[0].sightings.map(\.sentence).sorted(), ["樹皮が剥げた。", "樹皮の匂い。"])
        XCTAssertEqual(collections.collections().map(\.name), ["雑誌", "本"])
        XCTAssertEqual(lookups.lookups().map(\.headword), ["部屋", "円柱"])
        XCTAssertEqual(restored.cards, cards.cards())

        XCTAssertEqual(reports.count, 3)
        XCTAssertTrue(reports.allSatisfy { $0.0.deleted.isEmpty && $0.1 == .local })
        XCTAssertEqual(reports.map(\.0.saved.count), [1, 2, 1])

        // Once more changes nothing, and so writes and reports nothing.
        let again = try backup.restore(cards: cards, collections: collections, lookups: lookups)
        XCTAssertEqual(again.addedCards, 0)
        XCTAssertEqual(again.joinedCards, 0)
        XCTAssertEqual(reports.count, 3)
    }

    func testALookupFromBeforeTheHistoryWasClearedStaysGone() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("restore-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let cleared = day.addingTimeInterval(3600)
        let lookups = FileLookupHistory(
            url: folder.appendingPathComponent("lookups.json"), now: { cleared })
        try lookups.clear()
        let backup = Backup(
            created: day, cards: [],
            lookups: [
                Lookup(headword: "樹皮", reading: "じゅひ", entryID: 1, date: day, source: .page),
                Lookup(
                    headword: "円柱", reading: "えんちゅう", entryID: 2,
                    date: cleared.addingTimeInterval(60), source: .page),
            ])
        _ = try backup.restore(
            cards: FileCardStore(url: folder.appendingPathComponent("cards.json")),
            collections: FileCollectionStore(
                url: folder.appendingPathComponent("collections.json")),
            lookups: lookups)
        XCTAssertEqual(lookups.lookups().map(\.headword), ["円柱"])
    }

    func testTheFileIsNamedByTheDayWhereTheReaderIs() throws {
        // 23:30 in Greenwich on the 28th is 08:30 in Tokyo on the 29th.
        let night = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-28T23:30:00Z"))
        let tokyo = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
        let greenwich = try XCTUnwrap(TimeZone(identifier: "UTC"))
        XCTAssertEqual(Backup.fileName(at: night, timeZone: tokyo), "Yomidori backup 2026-09-29")
        XCTAssertEqual(
            Backup.fileName(at: night, timeZone: greenwich), "Yomidori backup 2026-09-28")
    }
}
