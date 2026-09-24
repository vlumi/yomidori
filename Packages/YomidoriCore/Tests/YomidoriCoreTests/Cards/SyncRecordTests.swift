import XCTest

@testable import YomidoriCore

final class SyncRecordTests: XCTestCase {
    func testNamesAreASCIIAndReadBack() throws {
        let id = UUID()
        let card = SyncName(.card, id.uuidString)
        XCTAssertEqual(card.recordName, "card-\(id.uuidString)")
        XCTAssertEqual(SyncName(recordName: card.recordName), card)
        let word = SyncName(.lookup, WordKey.of(headword: "頷く", reading: "うなずく"))
        XCTAssertTrue(word.recordName.allSatisfy(\.isASCII))
        XCTAssertLessThan(word.recordName.count, 255)
        XCTAssertEqual(SyncName(recordName: word.recordName), word)
        XCTAssertEqual(SyncName(recordName: SyncName.historyCleared.recordName), .historyCleared)
        XCTAssertNil(SyncName(recordName: "nonsense"))
        XCTAssertNil(SyncName(recordName: "deck-1"))
    }

    func testATooLongNameIsHashedAndFoundAmongKeys() {
        let key = WordKey.of(headword: "明けましておめでとうございます", reading: "あけましておめでとうございます")
        let name = SyncName(.lookup, key).recordName
        XCTAssertLessThanOrEqual(name.utf8.count, 255)
        XCTAssertTrue(name.allSatisfy(\.isASCII))
        XCTAssertTrue(name.hasPrefix("lookup-_"))
        XCTAssertNil(SyncName(recordName: name))
        XCTAssertEqual(SyncName.kind(ofRecordName: name), .lookup)
        XCTAssertEqual(SyncName.key(ofRecordName: name, among: ["他", key]), key)
        XCTAssertNil(SyncName.key(ofRecordName: name, among: ["他"]))
        let short = SyncName(.lookup, "他 た")
        XCTAssertEqual(SyncName.key(ofRecordName: short.recordName, among: []), short.key)
        // A short key starting with an underscore is spelled, not taken for a hash.
        XCTAssertEqual(SyncName(recordName: SyncName(.lookup, "_x").recordName)?.key, "_x")
    }

    func testACardTravelsWhole() throws {
        var card = Card(
            headword: "樹皮", reading: "じゅひ", entryID: 1,
            sightings: [
                Sighting(
                    sentence: "樹皮の匂い。", surface: "樹皮", offset: 0, source: nil,
                    date: Date(timeIntervalSince1970: 1_700_000_000))
            ],
            created: Date(timeIntervalSince1970: 1_700_000_000))
        card.start(at: Date(timeIntervalSince1970: 1_700_000_100))
        let back = try SyncPayload.decode(Card.self, from: SyncPayload.encode(card))
        XCTAssertEqual(back, card)
    }
}
