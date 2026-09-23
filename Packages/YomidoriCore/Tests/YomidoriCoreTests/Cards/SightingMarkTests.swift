import XCTest

@testable import YomidoriCore

final class SightingMarkTests: XCTestCase {
    func testTheSurfaceRangeFindsTheWord() throws {
        let sighting = Sighting(
            sentence: "彼女は黙って頷いた。", surface: "頷い", offset: 6, source: nil,
            date: Date())
        let range = try XCTUnwrap(sighting.surfaceRange)
        XCTAssertEqual(String(sighting.sentence[range]), "頷い")
    }

    func testACardsWordKeyIsTheHistorysToo() {
        let sighting = Sighting(
            sentence: "彼女は黙って頷いた。", surface: "頷い", offset: 6, source: nil, date: Date())
        let card = Card(
            headword: "頷く", reading: "うなずく", entryID: nil, sightings: [sighting], created: Date())
        XCTAssertEqual(card.wordKey, "頷く うなずく")
        XCTAssertEqual(
            card.wordKey,
            Lookup(headword: "頷く", reading: "うなずく", entryID: 1, date: Date(), source: .page).id)
    }

    func testARewrittenSentenceFindsTheWordAgain() {
        let sighting = Sighting(
            sentence: "彼女は黙って頷いた。", surface: "頷い", offset: 6, source: nil, date: Date())
        let corrected = sighting.withSentence("彼女は黙って頷いた。そして笑った。\n")
        XCTAssertEqual(corrected.offset, 6)
        XCTAssertEqual(corrected.id, sighting.id)
        let moved = sighting.withSentence("黙って頷いた。")
        XCTAssertEqual(moved.offset, 3)
        XCTAssertEqual(moved.surfaceRange.map { String(moved.sentence[$0]) }, "頷い")
        let gone = sighting.withSentence("彼女は黙っていた。")
        XCTAssertNil(gone.surfaceRange)
    }

    func testACardKeptWithPagePhotosStillReadsWithoutThem() throws {
        let json = """
            {"id":"\(UUID().uuidString)","sentence":"樹皮。","surface":"樹皮","offset":0,
             "stillIDs":["\(UUID().uuidString)"],"cropID":"\(UUID().uuidString)",
             "date":"2026-09-18T00:00:00Z"}
            """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let sighting = try decoder.decode(Sighting.self, from: Data(json.utf8))
        XCTAssertEqual(sighting.sentence, "樹皮。")
        let encoded = try XCTUnwrap(String(bytes: JSONEncoder().encode(sighting), encoding: .utf8))
        XCTAssertFalse(encoded.contains("stillIDs") || encoded.contains("cropID"))
    }

    func testAnOffsetPastTheSentenceGivesNoRange() {
        let sighting = Sighting(
            sentence: "短い。", surface: "頷い", offset: 6, source: nil, date: Date())
        XCTAssertNil(sighting.surfaceRange)
    }
}
