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

    func testACardJoinsCollectionsWhenKeptAndLeavesAForgottenOne() throws {
        let cards = FileCardStore(url: cardsURL)
        let sheep = UUID()
        let wood = UUID()
        let sighting = Sighting(
            sentence: "樹皮。", surface: "樹皮", offset: 0, stillIDs: [], source: nil, date: Date())
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
}
