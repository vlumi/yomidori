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
        // The lines' chunks and the line breaks, laid out once for the pages that draw by line.
        XCTAssertEqual(page.chunksByLine.flatMap { $0 }.map(\.id), page.chunks.map(\.id))
        XCTAssertEqual(page.chunksByLine.map { $0.first?.line }, [0, 1])
        XCTAssertEqual(
            page.lineBreaks, [text.distance(from: text.startIndex, to: text.firstIndex(of: "\n")!)])
        XCTAssertFalse(page.spansLines(7..<9))
        XCTAssertTrue(page.spansLines(5..<9))
    }

    func testChunksCoverWholeCharactersOfOddText() {
        for text in ["葛\u{E0100}の花", "天気\u{FE0F}です", "は\u{200D}い", "👩‍👩‍👧と\n👍🏽"] {
            let page = PageReading(
                text: text, tokens: SystemTokenizer().tokens(in:), dictionary: Stub())
            let characters = Array(text)
            for chunk in page.chunks {
                XCTAssertFalse(chunk.range.isEmpty, text)
                XCTAssertEqual(String(characters[chunk.range]), chunk.surface, text)
            }
        }
    }

    func testTheSentenceAroundASelection() {
        let page = read()
        // 部屋, on the second line, is in the sentence that began on the first.
        XCTAssertEqual(page.sentence(around: 7..<9), "樹皮の匂いが部屋に漂っていた。")
        XCTAssertEqual(page.sentence(around: 0..<2), "樹皮の匂いが部屋に漂っていた。")
        XCTAssertEqual(page.sentence(around: 99..<100), "")
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
        // A selection stretched to a chunk on either side of it, or inside it, grows or stays.
        XCTAssertEqual(PageReading.range(7..<9, stretchedTo: smell), 3..<9)
        XCTAssertEqual(PageReading.range(3..<5, stretchedTo: room), 3..<9)
        XCTAssertEqual(PageReading.range(3..<9, stretchedTo: room), 3..<9)
    }

    func testSegmentsKeepEveryPieceAndMarkTheWords() {
        let tokens = SystemTokenizer().tokens(in: "樹皮の匂い。")
        let segments = WordFinder.segments(in: tokens, dictionary: Stub())
        XCTAssertEqual(segments.map(\.word.surface), ["樹皮", "の", "匂い", "。"])
        XCTAssertEqual(segments.map(\.isShown), [true, false, true, false])
    }

    func testAPageWithoutLineBreaksReadsInTime() {
        // One long line: counting each segment's place from the line's start grew with the
        // square of the length, and twenty thousand characters took over a second.
        var text = ""
        while text.count < 20_000 { text += "吾輩は猫である。名前はまだ無い。どこで生まれたかとんと見当がつかぬ。" }
        let tokenizer = SystemTokenizer()
        let started = Date()
        let reading = PageReading(text: text, tokens: { tokenizer.tokens(in: $0) }, dictionary: nil)
        let took = Date().timeIntervalSince(started)
        XCTAssertGreaterThan(reading.chunks.count, 1_000)
        XCTAssertLessThan(took, 1.0, "read in \(took) s")
        // The ranges still index the text: the last chunk ends where the text does.
        XCTAssertEqual(reading.chunks.last?.range.upperBound, text.count)
    }
}
