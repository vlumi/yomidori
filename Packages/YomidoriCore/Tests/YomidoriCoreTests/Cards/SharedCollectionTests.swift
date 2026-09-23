import XCTest

@testable import YomidoriCore

final class SharedCollectionTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_700_000_000)
    private let book = Collection(name: "羊をめぐる冒険", note: "村上春樹", tags: ["book"])

    private func card(_ headword: String, _ reading: String, _ sentence: String, in ids: [UUID])
        -> Card
    {
        var card = Card(
            headword: headword, reading: reading, entryID: 1,
            sightings: [
                Sighting(
                    sentence: sentence, surface: headword, offset: 0, source: "p.12", date: date)
            ],
            created: date, collectionIDs: ids)
        card.start(at: date)
        card.answer(.reading, grade: .good, at: date)
        return card
    }

    func testTheFileCarriesTheWordsAndSentencesButNoPhotosOrReviews() throws {
        let cards = [
            card("樹皮", "じゅひ", "樹皮の匂いがした。", in: [book.id]),
            card("頷く", "うなずく", "彼女は頷いた。", in: [UUID()]),
        ]
        let shared = SharedCollection(collection: book, cards: cards)
        XCTAssertEqual(shared.words.map(\.headword), ["樹皮"])
        let data = try shared.encoded()
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertFalse(
            text.contains("stillIDs") || text.contains("cropID") || text.contains("review"))
        XCTAssertEqual(try SharedCollection.decoded(from: data), shared)
        XCTAssertThrowsError(try SharedCollection.decoded(from: Data("[]".utf8)))
    }

    func testMergingAddsNewWordsWaitingAndJoinsKnownOnesWithoutDoubles() throws {
        let shared = SharedCollection(
            collection: book,
            cards: [
                card("樹皮", "じゅひ", "樹皮の匂いがした。", in: [book.id]),
                card("相槌", "あいづち", "相槌を打った。", in: [book.id]),
            ])
        let mine = card("樹皮", "じゅひ", "樹皮の匂いがした。", in: [])
        let target = UUID()
        let merged = shared.merge(into: [mine], collection: target, at: date)
        XCTAssertEqual(merged.added, 1)
        XCTAssertEqual(merged.joined, 1)
        XCTAssertEqual(merged.cards[0].sightings.count, 1)
        XCTAssertEqual(merged.cards[0].collectionIDs, [target])
        XCTAssertNotNil(merged.cards[0].review)
        let new = merged.cards[1]
        XCTAssertEqual(new.headword, "相槌")
        XCTAssertTrue(new.isWaiting)
        XCTAssertNil(new.review)
        XCTAssertEqual(new.collectionIDs, [target])
        XCTAssertEqual(new.sightings.first?.source, "p.12")
    }

    func testAStoreTakesTheMergeInOneWrite() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = FileCardStore(url: url)
        var writes = 0
        store.file.onChange = { _, _ in writes += 1 }
        let shared = SharedCollection(
            collection: book, cards: [card("樹皮", "じゅひ", "樹皮の匂いがした。", in: [book.id])])
        try store.replaceAll { shared.merge(into: $0, collection: book.id, at: self.date).cards }
        XCTAssertEqual(writes, 1)
        XCTAssertEqual(FileCardStore(url: url).cards().map(\.headword), ["樹皮"])
    }
}
