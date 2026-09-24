import XCTest

@testable import YomidoriCore

final class FileCardStoreTests: XCTestCase {
    private var url: URL!

    override func setUp() {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cards-\(UUID().uuidString).json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: url)
    }

    private func sighting(
        _ sentence: String, _ surface: String, date: Date = Date(timeIntervalSince1970: 1_000_000)
    ) -> Sighting {
        let offset = sentence.distance(
            from: sentence.startIndex, to: sentence.range(of: surface)!.lowerBound)
        return Sighting(
            sentence: sentence, surface: surface, offset: offset, source: "羊をめぐる冒険 p.12", date: date
        )
    }

    func testAnEmptyStoreHasNoCards() {
        let store = FileCardStore(url: url)
        XCTAssertEqual(store.cards(), [])
        XCTAssertNil(store.card(headword: "頷く", reading: "うなずく"))
    }

    func testKeepingAWordMakesOneCardAndASecondSightingJoinsIt() throws {
        let store = FileCardStore(url: url)
        let first = try store.keep(
            sighting("彼女は黙って頷いた。", "頷い"), headword: "頷く", reading: "うなずく", entryID: 1270080)
        XCTAssertEqual(first.sightings.count, 1)
        XCTAssertEqual(first.sightings[0].offset, 6)
        let second = try store.keep(
            sighting("僕は何も言わずに頷いた。", "頷い", date: Date(timeIntervalSince1970: 2_000_000)),
            headword: "頷く", reading: "うなずく", entryID: 1270080)
        XCTAssertEqual(second.id, first.id)
        XCTAssertEqual(second.sightings.count, 2)
        XCTAssertEqual(store.cards().count, 1)
        XCTAssertEqual(store.cards()[0].created, first.sightings[0].date)
    }

    func testTheModifiedDateFollowsTheContentNotTheReviews() throws {
        let store = FileCardStore(url: url)
        let first = try store.keep(
            sighting("彼女は黙って頷いた。", "頷い"), headword: "頷く", reading: "うなずく", entryID: nil)
        XCTAssertEqual(first.modified, Date(timeIntervalSince1970: 1_000_000))
        let later = Date(timeIntervalSince1970: 2_000_000)
        var card = try store.keep(
            sighting("僕は頷いた。", "頷い", date: later), headword: "頷く", reading: "うなずく",
            entryID: nil)
        XCTAssertEqual(card.modified, later)
        card.answer(.reading, grade: .good, at: Date(timeIntervalSince1970: 3_000_000))
        XCTAssertEqual(card.modified, later)
        card.replace(
            card.sightings[0].withSentence("彼女は頷いた。"), at: Date(timeIntervalSince1970: 4_000_000))
        XCTAssertEqual(card.modified, Date(timeIntervalSince1970: 4_000_000))
        try store.update(card)
        XCTAssertEqual(FileCardStore(url: url).cards()[0].modified, card.modified)
    }

    func testEveryAnswerIsLogged() throws {
        var card = try FileCardStore(url: url).keep(
            sighting("樹皮の匂いがした。", "樹皮"), headword: "樹皮", reading: "じゅひ", entryID: nil)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        card.answer(.reading, grade: .again, at: now)
        card.answer(.reading, grade: .good, at: now.addingTimeInterval(600), reconciled: true)
        card.answer(.meaning, grade: .good, at: now)
        XCTAssertEqual(card.log.map(\.grade), [.again, .good, .good])
        XCTAssertEqual(card.log[1].reconciled, true)
        XCTAssertEqual(card.answers(to: .reading, graded: .good), 1)
        XCTAssertEqual(card.answers(to: .reading, graded: .again), 1)
        XCTAssertEqual(card.review?.reviews, 2)
        XCTAssertEqual(card.meaningReview?.reviews, 1)
        try FileCardStore(url: url).update(card)
        XCTAssertEqual(FileCardStore(url: url).cards()[0].log.count, 3)
    }

    func testTheSameKanjiWithAnotherReadingIsAnotherCard() throws {
        let store = FileCardStore(url: url)
        try store.keep(sighting("生地を買った。", "生地"), headword: "生地", reading: "きじ", entryID: 1)
        try store.keep(sighting("生地を訪ねた。", "生地"), headword: "生地", reading: "せいち", entryID: 2)
        XCTAssertEqual(store.cards().count, 2)
    }

    func testCardsSurviveAReopenAndDatesKeepTheirInstant() throws {
        try FileCardStore(url: url).keep(
            sighting("樹皮の匂いがした。", "樹皮"), headword: "樹皮", reading: "じゅひ", entryID: 1330370)
        let reopened = FileCardStore(url: url)
        let card = try XCTUnwrap(reopened.card(headword: "樹皮", reading: "じゅひ"))
        XCTAssertEqual(card.sightings[0].sentence, "樹皮の匂いがした。")
        XCTAssertEqual(card.sightings[0].date, Date(timeIntervalSince1970: 1_000_000))
        XCTAssertEqual(card.sightings[0].source, "羊をめぐる冒険 p.12")
    }

    func testRemovingACard() throws {
        let store = FileCardStore(url: url)
        let card = try store.keep(
            sighting("樹皮の匂いがした。", "樹皮"), headword: "樹皮", reading: "じゅひ", entryID: nil)
        try store.remove(card)
        XCTAssertEqual(store.cards(), [])
        XCTAssertEqual(FileCardStore(url: url).cards(), [])
    }

    func testAKeptCardWaitsUntilALessonStartsIt() throws {
        let store = FileCardStore(url: url)
        var card = try store.keep(
            sighting("樹皮の匂いがした。", "樹皮"), headword: "樹皮", reading: "じゅひ", entryID: nil)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertTrue(card.isWaiting)
        XCTAssertEqual(store.waiting().map(\.id), [card.id])
        XCTAssertTrue(store.dueItems(at: now).isEmpty)
        card.start(at: now)
        try store.update(card)
        XCTAssertEqual(store.dueItems(at: now).map(\.card.id), [card.id, card.id])
        XCTAssertTrue(store.waiting().isEmpty)
        card.answer(.reading, grade: .good, at: now)
        card.sendToWaiting()
        XCTAssertTrue(card.isWaiting)
        XCTAssertNil(card.review)
        XCTAssertEqual(card.log.count, 1)
        card.shelve()
        XCTAssertFalse(card.isWaiting)
        XCTAssertFalse(card.isInReview)
        try store.update(card)
        XCTAssertTrue(FileCardStore(url: url).cards()[0].shelved)
    }

    func testANewQuestionIsDueAndAnAnsweredOneWaitsUntilItsDate() throws {
        let store = FileCardStore(url: url)
        var card = try store.keep(
            sighting("樹皮の匂いがした。", "樹皮"), headword: "樹皮", reading: "じゅひ", entryID: nil)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        card.start(at: now)
        try store.update(card)
        XCTAssertEqual(store.dueItems(at: now).map(\.question), [.reading, .meaning])
        card.review = FSRS.review(nil, grade: .good, at: now)
        try store.update(card)
        XCTAssertEqual(store.dueItems(at: now).map(\.question), [.meaning])
        XCTAssertEqual(
            FileCardStore(url: url).dueItems(at: now.addingTimeInterval(4 * 86_400)).map(
                \.question),
            [.reading, .meaning])
    }

    func testTheOldOneStillShapeStillDecodes() throws {
        let still = UUID()
        let old = """
            [{"id":"\(UUID().uuidString)","headword":"樹皮","reading":"じゅひ","entryID":1,
              "created":"2026-09-18T00:00:00Z",
              "sightings":[{"id":"\(UUID().uuidString)","sentence":"樹皮。","surface":"樹皮","offset":0,
                            "stillID":"\(still.uuidString)","date":"2026-09-18T00:00:00Z"}]}]
            """
        try old.write(to: url, atomically: true, encoding: .utf8)
        let card = try XCTUnwrap(FileCardStore(url: url).cards().first)
        XCTAssertEqual(card.sightings[0].sentence, "樹皮。")
        XCTAssertEqual(card.modified, card.sightings[0].date)
        XCTAssertEqual(card.log, [])
    }

    func testEachQuestionIsItsOwnItemWithItsOwnSchedule() throws {
        let store = FileCardStore(url: url)
        var card = try store.keep(
            sighting("樹皮の匂いがした。", "樹皮"), headword: "樹皮", reading: "じゅひ", entryID: nil)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        card.start(at: now)
        try store.update(card)
        XCTAssertEqual(store.dueItems(at: now).map(\.question), [.reading, .meaning])
        XCTAssertEqual(
            store.dueItems(at: now, asksPitch: { _ in true }).map(\.question),
            [.reading, .meaning, .pitch])
        card.setState(FSRS.review(nil, grade: .good, at: now), for: .meaning)
        card.setState(FSRS.review(nil, grade: .good, at: now), for: .pitch)
        try store.update(card)
        XCTAssertEqual(
            store.dueItems(at: now, asksPitch: { _ in true }).map(\.question), [.reading])
        let reopened = FileCardStore(url: url).cards()[0]
        XCTAssertEqual(reopened.meaningReview?.reviews, 1)
        XCTAssertEqual(reopened.pitchReview?.reviews, 1)
        XCTAssertNil(reopened.review)
    }

    func testAnsweringOneQuestionKeepsTheAnswerToTheOther() throws {
        let store = FileCardStore(url: url)
        var card = try store.keep(
            sighting("樹皮の匂いがした。", "樹皮"), headword: "樹皮", reading: "じゅひ", entryID: nil)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        card.start(at: now)
        try store.update(card)
        // Both items hold the card as it was before either answer.
        let items = store.dueItems(at: now)
        XCTAssertEqual(items.map(\.question), [.reading, .meaning])
        try store.answer(items[0], grade: .good, at: now)
        try store.answer(items[1], grade: .again, at: now, reconciled: true, accepting: "tree bark")
        let reopened = try XCTUnwrap(FileCardStore(url: url).cards().first)
        XCTAssertEqual(reopened.review?.reviews, 1)
        XCTAssertEqual(reopened.meaningReview?.reviews, 1)
        XCTAssertEqual(reopened.log.map(\.question), [.reading, .meaning])
        XCTAssertEqual(reopened.acceptedMeanings, ["tree bark"])
    }

    func testTheStoreTellsItsListenerAfterEveryWrite() throws {
        let store = FileCardStore(url: url)
        var changes = 0
        store.file.onChange = { _, _ in changes += 1 }
        var card = try store.keep(
            sighting("樹皮の匂いがした。", "樹皮"), headword: "樹皮", reading: "じゅひ", entryID: nil)
        card.start(at: Date())
        try store.update(card)
        try store.remove(card)
        XCTAssertEqual(changes, 3)
    }

    func testThePitchIsLookedUpOnlyWhenItsQuestionIsDue() throws {
        let store = FileCardStore(url: url)
        var card = try store.keep(
            sighting("樹皮の匂いがした。", "樹皮"), headword: "樹皮", reading: "じゅひ", entryID: nil)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        card.start(at: now)
        card.setState(FSRS.review(nil, grade: .good, at: now), for: .pitch)
        try store.update(card)
        var lookups = 0
        _ = store.dueItems(
            at: now,
            asksPitch: { _ in
                lookups += 1; return true
            })
        XCTAssertEqual(lookups, 0)
        let later = now.addingTimeInterval(30 * 86_400)
        XCTAssertEqual(
            store.dueItems(
                at: later,
                asksPitch: { _ in
                    lookups += 1; return true
                }
            ).map(\.question),
            [.reading, .meaning, .pitch])
        XCTAssertEqual(lookups, 1)
    }

    func testACardWrittenWithTheMeaningToggleStillDecodesAndWaits() throws {
        let old = """
            [{"id":"\(UUID().uuidString)","headword":"樹皮","reading":"じゅひ","entryID":1,
              "created":"2026-09-18T00:00:00Z","asksMeaning":false,"sightings":[]}]
            """
        try old.write(to: url, atomically: true, encoding: .utf8)
        let card = try XCTUnwrap(FileCardStore(url: url).cards().first)
        XCTAssertTrue(card.isWaiting)
        XCTAssertEqual(card.dueQuestions(at: Date(), asksPitch: false), [])
    }

    func testACardReviewedBeforeTheLessonsCountsAsStarted() throws {
        let old = """
            [{"id":"\(UUID().uuidString)","headword":"樹皮","reading":"じゅひ","entryID":1,
              "created":"2026-09-18T00:00:00Z","sightings":[],
              "review":{"stability":3.1,"difficulty":5,"due":"2026-09-21T00:00:00Z",
                        "lastReview":"2026-09-18T00:00:00Z","reviews":1,"lapses":0}}]
            """
        try old.write(to: url, atomically: true, encoding: .utf8)
        let card = try XCTUnwrap(FileCardStore(url: url).cards().first)
        XCTAssertTrue(card.isInReview)
        XCTAssertEqual(card.started, card.review?.lastReview)
    }

    func testTheMostRecentlyAnsweredComeFirst() throws {
        let store = FileCardStore(url: url)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var old = try store.keep(
            sighting("樹皮の匂いがした。", "樹皮"), headword: "樹皮", reading: "じゅひ", entryID: nil)
        old.start(at: now.addingTimeInterval(-30 * 86_400))
        old.answer(.reading, grade: .good, at: now.addingTimeInterval(-20 * 86_400))
        try store.update(old)
        var fresh = try store.keep(
            sighting("彼女は頷いた。", "頷い"), headword: "頷く", reading: "うなずく", entryID: nil)
        fresh.start(at: now.addingTimeInterval(-60))
        try store.update(fresh)
        let items = store.dueItems(at: now)
        XCTAssertEqual(items.map(\.card.headword), ["頷く", "頷く", "樹皮", "樹皮"])
        XCTAssertEqual(items.map(\.question), [.reading, .meaning, .reading, .meaning])
    }

    func testTheFileIsReadableJSON() throws {
        try FileCardStore(url: url).keep(
            sighting("樹皮の匂いがした。", "樹皮"), headword: "樹皮", reading: "じゅひ", entryID: 1330370)
        let text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(text.contains("\"headword\" : \"樹皮\""))
        XCTAssertTrue(text.contains("1970-01-12T13:46:40Z"))
    }

    // TEMPORARY: goes with `keyCardsByWord`.
    func testOldCardsAreKeyedByTheirWordAndMergedWithTheirTwins() throws {
        let store = FileCardStore(url: url)
        let old = Card(
            id: UUID(), headword: "樹皮", reading: "じゅひ", entryID: 1,
            sightings: [sighting("樹皮の匂い。", "樹皮")], created: Date(timeIntervalSince1970: 10),
            acceptedMeanings: ["bark"], collectionIDs: [UUID()])
        let twin = Card(
            id: UUID(), headword: "樹皮", reading: "じゅひ", entryID: 1,
            sightings: [sighting("樹皮が剥げた。", "樹皮")], created: Date(timeIntervalSince1970: 20),
            collectionIDs: [UUID()])
        let other = Card(
            id: UUID(), headword: "部屋", reading: "へや", entryID: 2, sightings: [],
            created: Date(timeIntervalSince1970: 30))
        try store.replaceAll { _ in [old, twin, other] }
        var changes: [RecordChange] = []
        store.file.onChange = { change, _ in changes.append(change) }
        try store.keyCardsByWord()
        let cards = store.cards()
        XCTAssertEqual(cards.map(\.headword), ["樹皮", "部屋"])
        XCTAssertEqual(cards[0].id, WordKey.cardID(headword: "樹皮", reading: "じゅひ"))
        XCTAssertEqual(cards[0].sightings.count, 2)
        XCTAssertEqual(Set(cards[0].collectionIDs), Set(old.collectionIDs + twin.collectionIDs))
        XCTAssertEqual(cards[0].acceptedMeanings, ["bark"])
        XCTAssertEqual(cards[0].created, old.created)
        XCTAssertEqual(
            Set(changes.flatMap(\.deleted)), Set([old, twin, other].map(\.id.uuidString)))
        XCTAssertEqual(Set(changes.flatMap(\.saved)), Set(cards.map(\.id.uuidString)))
        // Once keyed, nothing more to do.
        changes = []
        try store.keyCardsByWord()
        XCTAssertTrue(changes.isEmpty)
    }
}
