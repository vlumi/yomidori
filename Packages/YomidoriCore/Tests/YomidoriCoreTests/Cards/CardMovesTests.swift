import XCTest

@testable import YomidoriCore

final class CardMovesTests: XCTestCase {
    private let day = Date(timeIntervalSince1970: 1_790_000_000)

    func testMovesAreKeptDatedReadWithoutAndMergedAsAUnion() throws {
        var card = Card(headword: "樹皮", reading: "じゅひ", entryID: nil, sightings: [], created: day)
        card.start(at: day)
        card.sendToWaiting(at: day.addingTimeInterval(86_400))
        card.shelve(at: day.addingTimeInterval(2 * 86_400))
        XCTAssertEqual(card.moves.map(\.standing), [.started, .waiting, .shelved])
        XCTAssertEqual(
            card.moves.map(\.date),
            [day, day.addingTimeInterval(86_400), day.addingTimeInterval(2 * 86_400)])
        XCTAssertTrue(card.shelved)
        XCTAssertNil(card.started)
        // A card written before moves were kept reads with none.
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoder.encode(card)) as? [String: Any])
        json["moves"] = nil
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let old = try decoder.decode(Card.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(old.moves, [])
        XCTAssertTrue(old.shelved)
        // Two devices' moves are one list, in date order, and the move counts as a touch.
        var phone = Card(headword: "樹皮", reading: "じゅひ", entryID: nil, sightings: [], created: day)
        phone.start(at: day)
        var mac = phone
        phone.sendToWaiting(at: day.addingTimeInterval(3 * 86_400))
        mac.answer(.reading, grade: .good, at: day.addingTimeInterval(2 * 86_400))
        let merged = mac.merged(with: phone)
        XCTAssertEqual(merged.moves.map(\.standing), [.started, .waiting])
        XCTAssertTrue(merged.isWaiting)
    }
}
