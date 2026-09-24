import XCTest

@testable import YomidoriCore

final class PageReadingTests: XCTestCase {
    private struct Stub: WordDictionary {
        let words: Set<String> = ["樹皮", "匂い", "部屋", "漂う", "見当がつく"]

        func entries(matching text: String) -> [DictionaryEntry] {
            guard words.contains(text) else { return [] }
            return [
                DictionaryEntry(
                    id: text.hashValue, kanji: [text], readings: [],
                    senses: [DictionaryEntry.Sense(partsOfSpeech: ["n"], glosses: ["g"])],
                    common: true)
            ]
        }
        func pitchAccents(for headword: String, reading: String) -> [PitchAccent] { [] }
        func search(_ query: String, limit: Int) -> [DictionaryEntry] { [] }
    }

    private let text = "樹皮の匂いが\n部屋に漂っていた。"

    private func read() -> PageReading {
        PageReading(text: text, tokens: SystemTokenizer().tokens(in:), dictionary: Stub())
    }

    func testThePageIsCutOnceIntoChunksThatCoverItWhole() {
        let page = read()
        XCTAssertEqual(
            page.chunks.map(\.surface).joined(), text.replacingOccurrences(of: "\n", with: ""))
        XCTAssertEqual(page.chunks.filter(\.isWord).map(\.surface), ["樹皮", "匂い", "部屋", "漂っ"])
        let room = page.chunks.first { $0.surface == "部屋" }
        XCTAssertEqual(room?.range, 7..<9)
        XCTAssertEqual(room?.line, 1)
        XCTAssertEqual(page.chunks.map(\.id), Array(page.chunks.indices))
    }

    func testAPlaceFindsItsChunkAndARangeTheChunksItTouches() {
        let page = read()
        XCTAssertEqual(page.chunk(at: 1)?.surface, "樹皮")
        XCTAssertEqual(page.chunk(at: 8)?.surface, "部屋")
        XCTAssertNil(page.chunk(at: 6))
        XCTAssertEqual(page.chunks(in: 1..<4).map(\.surface), ["樹皮", "の", "匂い"])
        XCTAssertEqual(page.whole(1..<4), 0..<5)
        XCTAssertNil(page.whole(6..<7))
    }

    func testTwoChunksMakeOneRangeAndItsPhraseDropsTheLineBreak() throws {
        let page = read()
        let smell = try XCTUnwrap(page.chunks.first { $0.surface == "匂い" })
        let room = try XCTUnwrap(page.chunks.first { $0.surface == "部屋" })
        let range = PageReading.range(from: room, to: smell)
        XCTAssertEqual(range, 3..<9)
        XCTAssertEqual(page.phrase(range), "匂いが部屋")
    }

    func testSegmentsKeepEveryPieceAndMarkTheWords() {
        let tokens = SystemTokenizer().tokens(in: "樹皮の匂い。")
        let segments = WordFinder.segments(in: tokens, dictionary: Stub())
        XCTAssertEqual(segments.map(\.word.surface), ["樹皮", "の", "匂い", "。"])
        XCTAssertEqual(segments.map(\.isShown), [true, false, true, false])
    }
}
