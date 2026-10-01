import XCTest

@testable import YomidoriCore

final class CollectionTests: XCTestCase {
    private var url: URL!
    private var cardsURL: URL!

    override func setUp() {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        url = base.appendingPathExtension("collections.json")
        cardsURL = base.appendingPathExtension("cards.json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(at: cardsURL)
    }

    func testTagsMatchCaseAside() {
        XCTAssertTrue(["Book", "Magazine"].containsTag("book"))
        XCTAssertFalse(["Book"].containsTag("books"))
        XCTAssertTrue(Collection(name: "羊", tags: ["SF"]).hasTag("sf"))
    }

    func testACardIsInTheChosenCollectionsOrInAllWhenNoneIsChosen() {
        let book = UUID()
        var card = Card(headword: "羊", reading: "ひつじ", entryID: nil, sightings: [], created: Date())
        XCTAssertTrue(card.isIn(anyOf: []))
        XCTAssertFalse(card.isIn(anyOf: [book]))
        card.add(to: book)
        XCTAssertTrue(card.isIn(anyOf: [book, UUID()]))
        // In no collection: none on the card, or only ones that are no more.
        XCTAssertFalse(card.isInNone(of: [book]))
        XCTAssertTrue(card.isInNone(of: [UUID()]))
        XCTAssertTrue(card.isInNone(of: []))
        card.remove(from: book)
        XCTAssertTrue(card.isInNone(of: [book]))
    }

    func testCollectionsAreMadeRenamedRemovedAndReopened() throws {
        let store = FileCollectionStore(url: url)
        XCTAssertEqual(store.collections(), [])
        var book = Collection(name: "羊をめぐる冒険")
        try store.save(book)
        try store.save(Collection(name: "ノルウェイの森"))
        XCTAssertEqual(store.collections().map(\.name), ["羊をめぐる冒険", "ノルウェイの森"])
        book.name = "羊"
        try store.save(book)
        XCTAssertEqual(FileCollectionStore(url: url).collections().map(\.name), ["羊", "ノルウェイの森"])
        try store.remove(book)
        XCTAssertEqual(store.collections().map(\.name), ["ノルウェイの森"])
    }

    func testTagsNoteAndCoverAreKeptAndOldFilesReadWithoutThem() throws {
        let store = FileCollectionStore(url: url)
        let cover = UUID()
        try store.save(
            Collection(name: "羊", note: "村上春樹", tags: ["book", "novel", "Book"], coverID: cover))
        let reopened = FileCollectionStore(url: url).collections()[0]
        XCTAssertEqual(reopened.note, "村上春樹")
        XCTAssertEqual(reopened.tags, ["book", "novel", "Book"])
        XCTAssertEqual(reopened.coverID, cover)
        let old = """
            [{"id":"\(UUID().uuidString)","name":"古い","created":"2026-09-22T00:00:00Z"}]
            """
        try old.write(to: url, atomically: true, encoding: .utf8)
        let plain = FileCollectionStore(url: url).collections()[0]
        XCTAssertEqual(plain.tags, [])
        XCTAssertNil(plain.coverID)
    }

    func testTagsFromTextAndAcrossCollections() {
        XCTAssertEqual(
            Collection.tags(from: " book, Novel ,,novel、game "), ["book", "Novel", "game"])
        let collections = [
            Collection(name: "a", tags: ["book", "novel"]),
            Collection(name: "b", tags: ["Book", "game"]),
        ]
        XCTAssertEqual(collections.allTags, ["book", "novel", "game"])
    }

    func testACardJoinsCollectionsWhenKeptAndLeavesAForgottenOne() throws {
        let cards = FileCardStore(url: cardsURL)
        let sheep = UUID()
        let wood = UUID()
        let sighting = Sighting(
            sentence: "樹皮。", surface: "樹皮", offset: 0, source: nil, date: Date())
        var card = try cards.keep(
            sighting, headword: "樹皮", reading: "じゅひ", entryID: nil, collection: sheep)
        XCTAssertEqual(card.collectionIDs, [sheep])
        card = try cards.keep(
            sighting, headword: "樹皮", reading: "じゅひ", entryID: nil, collection: wood)
        XCTAssertEqual(card.collectionIDs, [sheep, wood])
        card = try cards.keep(
            sighting, headword: "樹皮", reading: "じゅひ", entryID: nil, collection: sheep)
        XCTAssertEqual(card.collectionIDs, [sheep, wood])
        XCTAssertEqual(card.sightings.count, 3)
        try cards.forget(collection: sheep)
        XCTAssertEqual(FileCardStore(url: cardsURL).cards()[0].collectionIDs, [wood])
        var edited = cards.cards()[0]
        edited.remove(from: wood)
        XCTAssertEqual(edited.collectionIDs, [])
    }

    func testARestoreIsOneWriteAndAnotherDevicesChangesAreNotSentBack() throws {
        let store = FileCollectionStore(url: url)
        let sheep = Collection(name: "羊をめぐる冒険")
        let forest = Collection(name: "ノルウェイの森")
        try store.save(sheep)
        var reports: [(RecordChange, ChangeOrigin)] = []
        store.file.onChange = { reports.append(($0, $1)) }

        try store.replaceAll { $0 + [forest, Collection(name: "海辺のカフカ")] }
        XCTAssertEqual(store.collections().map(\.name), ["羊をめぐる冒険", "ノルウェイの森", "海辺のカフカ"])
        XCTAssertEqual(reports.count, 1)
        XCTAssertEqual(reports[0].0.saved.count, 2)
        XCTAssertEqual(reports[0].1, .local)

        // From another device: one renamed, one gone, one new.
        var renamed = sheep
        renamed.name = "羊"
        let kafka = try XCTUnwrap(store.collections().last)
        let dance = Collection(name: "ダンス・ダンス・ダンス")
        try store.applyRemote(saving: [renamed, dance], deleting: [kafka.id])
        XCTAssertEqual(
            FileCollectionStore(url: url).collections().map(\.name),
            ["羊", "ノルウェイの森", "ダンス・ダンス・ダンス"])
        XCTAssertEqual(reports.count, 2)
        XCTAssertEqual(reports[1].1, .remote)
        XCTAssertEqual(reports[1].0.deleted, [kafka.id.uuidString])
        XCTAssertEqual(Set(reports[1].0.saved), [sheep.id.uuidString, dance.id.uuidString])
    }

    func testManyCardsJoinAndLeaveACollectionInOneWrite() throws {
        let cards = FileCardStore(url: cardsURL)
        let book = UUID()
        let other = UUID()
        let sighting = Sighting(sentence: "", surface: "", offset: 0, source: nil, date: Date())
        let bark = try cards.keep(
            sighting, headword: "樹皮", reading: "じゅひ", entryID: nil, collection: nil)
        let room = try cards.keep(
            sighting, headword: "部屋", reading: "へや", entryID: nil, collection: book)
        let cat = try cards.keep(
            sighting, headword: "猫", reading: "ねこ", entryID: nil, collection: other)
        var reports: [RecordChange] = []
        cards.file.onChange = { change, _ in reports.append(change) }

        // 部屋 is in the book already: two are new to it, and one write says so.
        XCTAssertEqual(try cards.add([bark.id, room.id, cat.id], to: book), 2)
        XCTAssertEqual(reports.count, 1)
        XCTAssertEqual(Set(reports[0].saved), [bark.id.uuidString, cat.id.uuidString])
        XCTAssertEqual(cards.card(id: cat.id)?.collectionIDs, [other, book])
        // Again changes nothing, and writes nothing.
        XCTAssertEqual(try cards.add([bark.id, room.id], to: book), 0)
        XCTAssertEqual(reports.count, 1)

        // Out of the book: only those chosen, only where they were in it.
        XCTAssertEqual(try cards.remove([bark.id, UUID()], from: book), 1)
        XCTAssertEqual(reports.count, 2)
        XCTAssertEqual(cards.card(id: bark.id)?.collectionIDs, [])
        XCTAssertEqual(cards.card(id: room.id)?.collectionIDs, [book])
        XCTAssertEqual(try cards.remove([bark.id], from: book), 0)
        XCTAssertEqual(FileCardStore(url: cardsURL).card(id: cat.id)?.collectionIDs, [other, book])
    }
}
