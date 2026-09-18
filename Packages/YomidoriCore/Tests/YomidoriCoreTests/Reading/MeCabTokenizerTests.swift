import XCTest
import YomidoriCore

@testable import YomidoriMeCab

/// The same fixture as the system tokenizer's, through MeCab with IPADic, so the two
/// stay comparable as the fixture grows.
final class MeCabTokenizerTests: XCTestCase {
    private let mecab = MeCabTokenizer.shared

    private func token(_ word: String, in sentence: String) -> Token? {
        mecab?.tokens(in: sentence).first { $0.surface == word }
    }

    func testLoads() {
        XCTAssertNotNil(mecab)
    }

    func testReadingsOfHardWordsInContext() {
        XCTAssertEqual(token("薄暮", in: "彼は薄暮の中で煙草に火を点けた。")?.reading, "はくぼ")
        XCTAssertEqual(token("樹皮", in: "樹皮の匂いが部屋に漂っていた。")?.reading, "じゅひ")
        XCTAssertEqual(token("頷い", in: "彼女は黙って頷いた。")?.reading, "うなずい")
        XCTAssertEqual(token("曖昧", in: "僕は曖昧に微笑んだ。")?.reading, "あいまい")
        XCTAssertEqual(token("躊躇", in: "彼は躊躇なくその扉を開けた。")?.reading, "ちゅうちょ")
        XCTAssertEqual(token("相槌", in: "羊男は相槌を打ちながら耳を傾けた。")?.reading, "あいづち")
    }

    func testTheSameKanjiReadsByContext() {
        let sentence = "生地を生のまま食べる人生もある。"
        XCTAssertEqual(token("生地", in: sentence)?.reading, "きじ")
        XCTAssertEqual(token("生", in: sentence)?.reading, "なま")
    }

    func testInflectedVerbsCarryTheirDictionaryForm() {
        XCTAssertEqual(token("頷い", in: "彼女は黙って頷いた。")?.dictionaryForm, "頷く")
        XCTAssertEqual(token("漂っ", in: "樹皮の匂いが部屋に漂っていた。")?.dictionaryForm, "漂う")
        XCTAssertNil(token("樹皮", in: "樹皮の匂いが部屋に漂っていた。")?.dictionaryForm)
    }

    func testPunctuationIsKeptButIsNotAWord() {
        let tokens = mecab?.tokens(in: "「はい」と彼は言った。") ?? []
        XCTAssertEqual(tokens.map(\.surface).joined(), "「はい」と彼は言った。")
        XCTAssertEqual(tokens.filter { !$0.isWord }.map(\.surface), ["「", "」", "。"])
    }
}
