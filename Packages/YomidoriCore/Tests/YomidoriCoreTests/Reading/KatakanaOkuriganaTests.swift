import XCTest

@testable import YomidoriCore

final class KatakanaOkuriganaTests: XCTestCase {
    /// Loanwords and the short words and single kana JMdict also lists in katakana.
    private let listed: Set<String> = ["タワー", "チーム", "ガイド", "シ", "ハ", "ニ", "ズ", "ザル", "タイ", "パン"]

    private func folded(_ line: String) -> String? {
        KatakanaOkurigana.folded(line, isWord: listed.contains)
    }

    func testTheOldStylesKatakanaIsReadAsHiragana() {
        XCTAssertEqual(folded("但シ、本日ヨリ一切ノ外出ヲ禁ズ。"), "但し、本日より一切の外出を禁ず。")
        XCTAssertEqual(folded("命令ニ従ハザル者ハ処刑スル。"), "命令に従はざる者は処刑する。")
        // Short words the dictionary has in katakana are not loanwords here.
        XCTAssertEqual(folded("此処ニ行キタイ"), "此処に行きたい")
    }

    func testLoanwordsStayAsWritten() {
        XCTAssertEqual(folded("東京タワーニ行ク"), "東京タワーに行く")
        XCTAssertEqual(folded("中国語ガイドヲ読ム"), "中国語ガイドを読む")
        XCTAssertEqual(folded("朝ニパンヲ食ス"), "朝にパンを食す")
    }

    func testALineWithHiraganaOrWithoutKanjiIsLeftAlone() {
        XCTAssertNil(folded("日本チームが勝った。"))
        XCTAssertNil(folded("ヨロシク"))
        XCTAssertNil(folded("東京タワー"))
        XCTAssertNil(folded("本日休業"))
    }

    func testTokensKeepThePagesSpellingAndItsPlace() {
        let line = "但シ、本日ヨリ"
        let tokens = KatakanaOkurigana.tokens(
            in: line, tokenizer: SystemTokenizer().tokens(in:), isWord: listed.contains)
        XCTAssertEqual(tokens.map(\.surface), ["但し", "、", "本日", "より"])
        XCTAssertEqual(tokens.map { $0.written ?? $0.surface }, ["但シ", "、", "本日", "ヨリ"])
        XCTAssertEqual(tokens.map { String(line[$0.range]) }, ["但シ", "、", "本日", "ヨリ"])
        XCTAssertNil(tokens[2].written)
    }

    func testARewrittenSentenceFindsAFoldedWordAgain() {
        let sighting = Sighting(
            sentence: "但シ、本日ヨリ禁ズ。", surface: "より", offset: 5, source: nil, date: Date())
        XCTAssertEqual(sighting.withSentence("但シ、本日ヨリ禁ズ。").offset, 5)
        XCTAssertEqual(sighting.withSentence("本日ヨリ禁ズ。").offset, 2)
    }
}
