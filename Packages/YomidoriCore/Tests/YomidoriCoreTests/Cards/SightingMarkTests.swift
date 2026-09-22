import XCTest

@testable import YomidoriCore

final class SightingMarkTests: XCTestCase {
    func testTheSurfaceRangeFindsTheWord() throws {
        let sighting = Sighting(
            sentence: "彼女は黙って頷いた。", surface: "頷い", offset: 6, stillIDs: [], source: nil,
            date: Date())
        let range = try XCTUnwrap(sighting.surfaceRange)
        XCTAssertEqual(String(sighting.sentence[range]), "頷い")
    }

    func testTheImagesAreTheCropThenThePagesAndTheCardsKnowThemAll() {
        let crop = UUID(), page = UUID(), other = UUID()
        let sighting = Sighting(
            sentence: "彼女は黙って頷いた。", surface: "頷い", offset: 6, stillIDs: [page], cropID: crop,
            source: nil, date: Date())
        XCTAssertEqual(sighting.imageIDs, [crop, page])
        let card = Card(
            headword: "頷く", reading: "うなずく", entryID: nil, sightings: [sighting], created: Date())
        XCTAssertEqual([card].referencedImageIDs, [crop, page])
        XCTAssertFalse([card].referencedImageIDs.contains(other))
        XCTAssertEqual(card.wordKey, "頷く うなずく")
        XCTAssertEqual(
            card.wordKey,
            Lookup(headword: "頷く", reading: "うなずく", entryID: 1, date: Date(), source: .page).id)
    }

    func testARewrittenSentenceFindsTheWordAgain() {
        let sighting = Sighting(
            sentence: "彼女は黙って頷いた。", surface: "頷い", offset: 6, stillIDs: [UUID()],
            cropID: UUID(), source: nil, date: Date())
        let corrected = sighting.withSentence("彼女は黙って頷いた。そして笑った。\n")
        XCTAssertEqual(corrected.offset, 6)
        XCTAssertEqual(corrected.id, sighting.id)
        XCTAssertEqual(corrected.stillIDs, sighting.stillIDs)
        let moved = sighting.withSentence("黙って頷いた。")
        XCTAssertEqual(moved.offset, 3)
        XCTAssertEqual(moved.surfaceRange.map { String(moved.sentence[$0]) }, "頷い")
        let gone = sighting.withSentence("彼女は黙っていた。")
        XCTAssertNil(gone.surfaceRange)
    }

    func testImagesCanBeDroppedFromASighting() {
        let sighting = Sighting(
            sentence: "樹皮。", surface: "樹皮", offset: 0, stillIDs: [UUID()], cropID: UUID(),
            source: nil, date: Date())
        XCTAssertTrue(sighting.hasImages)
        let bare = sighting.withoutImages()
        XCTAssertFalse(bare.hasImages)
        XCTAssertEqual(bare.sentence, sighting.sentence)
        var card = Card(
            headword: "樹皮", reading: "じゅひ", entryID: nil, sightings: [sighting], created: Date())
        card.replace(bare)
        XCTAssertEqual(card.sightings, [bare])
    }

    func testAnOffsetPastTheSentenceGivesNoRange() {
        let sighting = Sighting(
            sentence: "短い。", surface: "頷い", offset: 6, stillIDs: [], source: nil, date: Date())
        XCTAssertNil(sighting.surfaceRange)
    }
}
