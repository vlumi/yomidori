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

    func testAnOffsetPastTheSentenceGivesNoRange() {
        let sighting = Sighting(
            sentence: "短い。", surface: "頷い", offset: 6, stillIDs: [], source: nil, date: Date())
        XCTAssertNil(sighting.surfaceRange)
    }
}
