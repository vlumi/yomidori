import XCTest

@testable import YomidoriCore

final class IntakeTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_700_000_000)

    private func shared(_ json: String) throws -> SharedCollection {
        try SharedCollection.decoded(from: Data(json.utf8))
    }

    func testASharedCollectionIsCleanedAndBounded() throws {
        let long = String(repeating: "あ", count: 5_000)
        let collection = try shared(
            """
            {"format":"yomidori-collection","version":1,"name":"\\u202e羊","note":"\(long)",
             "tags":["book","\\u0000"],
             "words":[
               {"headword":"樹皮","reading":"じゅひ","sentences":[
                 {"sentence":"樹皮の匂い。","surface":"樹皮","offset":99},
                 {"sentence":"\(long)","surface":"樹皮","offset":0}]},
               {"headword":"","reading":"から","sentences":[]}]}
            """)
        XCTAssertEqual(collection.name, "羊")
        XCTAssertEqual(collection.note.count, Intake.noteLength)
        XCTAssertEqual(collection.tags, ["book"])
        XCTAssertEqual(collection.words.map(\.headword), ["樹皮"])
        XCTAssertEqual(collection.words[0].sentences[0].offset, -1)
        XCTAssertEqual(collection.words[0].sentences[1].sentence.count, Intake.sentenceLength)
    }

    func testFilesThatAreTooLargeNamelessOrOfAnotherFormatAreRefused() {
        XCTAssertThrowsError(
            try SharedCollection.decoded(from: Data(count: SharedCollection.largestFile + 1)))
        XCTAssertThrowsError(
            try shared(
                #"{"format":"yomidori-collection","version":1,"name":"\u202e","note":"","#
                    + #""tags":[],"words":[]}"#
            ))
        XCTAssertThrowsError(
            try shared(#"{"format":"other","version":1,"name":"x","note":"","tags":[],"words":[]}"#)
        )
        XCTAssertThrowsError(
            try shared(
                #"{"format":"yomidori-collection","version":2,"name":"x","note":"","tags":[],"words":[]}"#
            ))
    }

    func testARecordFromAnotherDeviceIsCleanedAndABrokenScheduleDropped() throws {
        var card = Card(
            headword: "樹皮\u{202D}", reading: "じゅひ", entryID: 1,
            sightings: [
                Sighting(sentence: "樹皮。", surface: "樹皮", offset: 5, source: nil, date: date)
            ],
            created: date)
        card.start(at: date)
        card.review = ReviewState(
            stability: -1, difficulty: 5, due: date, lastReview: date, reviews: 1, lapses: 0)
        card.meaningReview = ReviewState(
            stability: 3, difficulty: 40, due: date, lastReview: date, reviews: -2, lapses: 0)
        let clean = try XCTUnwrap(SyncPayload.intake(Card.self, from: SyncPayload.encode(card)))
        XCTAssertEqual(clean.headword, "樹皮")
        XCTAssertNil(clean.review)
        XCTAssertEqual(clean.meaningReview?.difficulty, 10)
        XCTAssertEqual(clean.meaningReview?.reviews, 0)
        XCTAssertEqual(clean.sightings[0].offset, -1)
        XCTAssertNil(SyncPayload.intake(Card.self, from: Data(count: SyncPayload.largest + 1)))
        XCTAssertNil(
            Lookup(headword: "\u{0007}", reading: "", entryID: 1, date: date, source: .page)
                .sanitized())
        XCTAssertNil(Collection(name: " \u{202E}".trimmingCharacters(in: .whitespaces)).sanitized())
    }

    func testAClearFromTheFutureIsNotTakenAndTheSchedulerSurvivesABrokenState() {
        XCTAssertNil(SyncPayload.clearDate(date.addingTimeInterval(3 * 86_400), now: date))
        XCTAssertEqual(SyncPayload.clearDate(date, now: date), date)
        let broken = ReviewState(
            stability: 0, difficulty: 5, due: date, lastReview: date, reviews: 1, lapses: 0)
        XCTAssertTrue(
            FSRS.review(broken, grade: .good, at: date.addingTimeInterval(86_400)).due > date)
    }
}
