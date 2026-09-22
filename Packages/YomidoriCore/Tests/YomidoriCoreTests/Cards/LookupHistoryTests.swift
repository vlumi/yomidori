import XCTest

@testable import YomidoriCore

final class LookupHistoryTests: XCTestCase {
    private var url: URL!

    override func setUp() {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lookups-\(UUID().uuidString).json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: url)
    }

    private func lookup(_ headword: String, day: Int, source: Lookup.Source = .search) -> Lookup {
        Lookup(
            headword: headword, reading: headword, entryID: headword.hashValue,
            date: Date(timeIntervalSince1970: Double(day) * 86_400), source: source)
    }

    func testAWordIsOneLineNewestFirstAndCanGo() throws {
        let history = FileLookupHistory(url: url)
        try history.record(lookup("樹皮", day: 1))
        try history.record(lookup("頷く", day: 2, source: .page))
        try history.record(lookup("樹皮", day: 3))
        XCTAssertEqual(history.lookups().map(\.headword), ["樹皮", "頷く"])
        XCTAssertEqual(history.lookups()[0].date, Date(timeIntervalSince1970: 3 * 86_400))
        XCTAssertEqual(FileLookupHistory(url: url).lookups()[1].source, .page)
        try history.remove(lookup("樹皮", day: 0))
        XCTAssertEqual(history.lookups().map(\.headword), ["頷く"])
        try history.clear()
        XCTAssertEqual(FileLookupHistory(url: url).lookups(), [])
    }

    func testTheHistoryIsCapped() throws {
        let history = FileLookupHistory(url: url)
        for day in 0..<(FileLookupHistory.limit + 5) {
            try history.record(lookup("語\(day)", day: day))
        }
        XCTAssertEqual(history.lookups().count, FileLookupHistory.limit)
        XCTAssertEqual(history.lookups().first?.headword, "語\(FileLookupHistory.limit + 4)")
    }

    func testParticlesAndAuxiliariesAreNotWorthALine() {
        func entry(_ pos: [[String]]) -> DictionaryEntry {
            DictionaryEntry(
                id: 1, kanji: [], readings: ["x"],
                senses: pos.map { DictionaryEntry.Sense(partsOfSpeech: $0, glosses: ["g"]) },
                common: false)
        }
        XCTAssertFalse(Lookup.isWorthKeeping(entry([["prt"]])))
        XCTAssertFalse(Lookup.isWorthKeeping(entry([["aux-v"], ["cop"]])))
        XCTAssertTrue(Lookup.isWorthKeeping(entry([["prt"], ["n"]])))
        XCTAssertTrue(Lookup.isWorthKeeping(entry([["adv"]])))
        XCTAssertTrue(Lookup.isWorthKeeping(entry([[]])))
    }
}
