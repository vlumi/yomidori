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

    func testAClosingQuoteAfterTheFullStopStaysWithTheSentence() {
        let text = "「はい。」と彼女は言った。"
        XCTAssertEqual(Sentence.around(text.startIndex, in: text).text, text)
        XCTAssertEqual(Sentence.around(text.range(of: "彼女")!.lowerBound, in: text).text, text)
        // A closing quote at the very start has no opener to pair with, and counts for nothing.
        XCTAssertEqual(Sentence.around(text.startIndex, in: "」だけ。").text, "」だけ。")
    }

    func testTheOffsetCountsCharactersWithoutTheLineBreak() {
        let sentence = Sentence.around(index(of: "漂っ"), in: page)
        XCTAssertEqual(sentence.offset(of: index(of: "漂っ"), in: page), 9)
        XCTAssertEqual(String(sentence.text.dropFirst(9).prefix(2)), "漂っ")
    }

    func testTheParagraphIndentIsNeitherInTheSentenceNorInTheOffset() {
        let text = "前の文。\n　吾輩は猫である。名前はまだ無い。"
        let cat = text.range(of: "猫")!.lowerBound
        let sentence = Sentence.around(cat, in: text)
        XCTAssertEqual(sentence.text, "吾輩は猫である。")
        XCTAssertEqual(sentence.offset(of: cat, in: text), 3)
        XCTAssertEqual(String(sentence.text.dropFirst(3).prefix(1)), "猫")
    }
}

extension SentenceTests {
    private func sentence(around word: String, in text: String) -> String {
        Sentence.around(text.range(of: word)!.lowerBound, in: text).text
    }

    func testAQuotationStaysWithWhatFollowsIt() {
        let text = "前の文。「はい。」と彼女は言った。次の文。"
        XCTAssertEqual(sentence(around: "はい", in: text), "「はい。」と彼女は言った。")
        XCTAssertEqual(sentence(around: "彼女", in: text), "「はい。」と彼女は言った。")
        let muttered = "彼は「もう帰る」と呟いた。"
        XCTAssertEqual(sentence(around: "帰る", in: muttered), muttered)
        XCTAssertEqual(sentence(around: "呟い", in: muttered), muttered)
        // A full stop inside the quote ends nothing, even across a wrapped line.
        let wrapped = "彼は「もう帰る。疲れ\nた」と呟いた。"
        XCTAssertEqual(sentence(around: "疲れ", in: wrapped), "彼は「もう帰る。疲れた」と呟いた。")
    }

    func testDialogueLinesAreSentencesOfTheirOwn() {
        let text = "「おはよう」\n「おはよう。元気？」\n　彼女は頷いた。"
        XCTAssertEqual(sentence(around: "元気", in: text), "「おはよう。元気？」")
        XCTAssertEqual(sentence(around: "頷い", in: text), "彼女は頷いた。")
        XCTAssertEqual(sentence(around: "おはよう", in: text), "「おはよう」")
        // The indent lost to the recognizer: the full stop inside and the line break after
        // still end the quotation.
        let unindented = "「はい。」\n彼女は頷いた。"
        XCTAssertEqual(sentence(around: "頷い", in: unindented), "彼女は頷いた。")
        XCTAssertEqual(sentence(around: "はい", in: unindented), "「はい。」")
    }

    func testAPageNumberNeverJoinsASentence() {
        let text = "窓の外では雪が音もなく降り続け\n123\n第二章\n朝になった。"
        let open = Sentence.around(text.range(of: "降り")!.lowerBound, in: text)
        XCTAssertEqual(open.text, "窓の外では雪が音もなく降り続け")
        XCTAssertTrue(open.isOpen)
        XCTAssertEqual(sentence(around: "朝に", in: "— 12 —\n朝になった。"), "朝になった。")
    }

    func testALongQuotationIsCutAtItsOwnFullStops() {
        let speech = String(repeating: "長い話が続く。", count: 20)
        let text = "彼は言った。「\(speech)もう帰る。」と呟いた。"
        XCTAssertEqual(sentence(around: "帰る", in: text), "もう帰る。」")
        // A quotation open at the top of the page, closed on the next: the same.
        let unclosed = "「\(speech)もう帰る。"
        XCTAssertEqual(sentence(around: "帰る", in: unclosed), "もう帰る。")
    }
}
