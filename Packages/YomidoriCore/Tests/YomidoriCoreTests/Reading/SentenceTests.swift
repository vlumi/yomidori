import XCTest

@testable import YomidoriCore

final class SentenceTests: XCTestCase {
    private let page = """
        彼は薄暮の中で煙草に火を点けた。樹皮の匂いが部
        屋に漂っていた。「はい」と彼女は言った。彼女は黙って
        頷いた。窓の外では雪が音もなく降り続け
        """

    private func index(of word: String) -> String.Index {
        page.range(of: word)!.lowerBound
    }

    func testTheSentenceAroundAWordSpansWrappedLines() {
        let sentence = Sentence.around(index(of: "樹皮"), in: page)
        XCTAssertEqual(sentence.text, "樹皮の匂いが部屋に漂っていた。")
        XCTAssertFalse(sentence.isOpen)
        XCTAssertEqual(Sentence.around(index(of: "点け"), in: page).text, "彼は薄暮の中で煙草に火を点けた。")
    }

    func testQuotesStayWithTheirSentence() {
        let sentence = Sentence.around(index(of: "彼女は言"), in: page)
        XCTAssertEqual(sentence.text, "「はい」と彼女は言った。")
        XCTAssertEqual(Sentence.around(index(of: "頷い"), in: page).text, "彼女は黙って頷いた。")
    }

    func testTheLastSentenceOfAPageIsOpenWhenItHasNoFullStop() {
        let sentence = Sentence.around(index(of: "降り"), in: page)
        XCTAssertEqual(sentence.text, "窓の外では雪が音もなく降り続け")
        XCTAssertTrue(sentence.isOpen)
    }

    func testTheContinuationIsTheNextPageUpToItsFirstFullStop() {
        let next = "ていた。彼は躊躇なくその扉を開けた。"
        let continuation = Sentence.continuation(of: next)
        XCTAssertEqual(continuation.text, "ていた。")
        XCTAssertFalse(continuation.isOpen)
        XCTAssertEqual(Sentence.continuation(of: "\n\n").text, "")
    }

    func testTheOffsetCountsCharactersWithoutTheLineBreak() {
        let sentence = Sentence.around(index(of: "漂っ"), in: page)
        XCTAssertEqual(sentence.offset(of: index(of: "漂っ"), in: page), 9)
        XCTAssertEqual(String(sentence.text.dropFirst(9).prefix(2)), "漂っ")
    }
}
