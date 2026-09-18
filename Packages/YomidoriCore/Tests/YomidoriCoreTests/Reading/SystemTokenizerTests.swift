import XCTest

@testable import YomidoriCore

/// The tokenizer spike's fixture: literary sentences with the readings a reader
/// wants, and the reading the system analyzer gives for each in context.
final class SystemTokenizerTests: XCTestCase {
    private func reading(of word: String, in sentence: String) -> String? {
        SystemTokenizer.tokens(in: sentence).first { $0.surface == word }?.reading
    }

    private struct Case {
        let sentence: String
        let word: String
        let reading: String

        init(_ sentence: String, _ word: String, _ reading: String) {
            self.sentence = sentence
            self.word = word
            self.reading = reading
        }
    }

    func testReadingsOfHardWordsInContext() {
        let cases: [Case] = [
            Case("彼は薄暮の中で煙草に火を点けた。", "薄暮", "はくぼ"),
            Case("彼は薄暮の中で煙草に火を点けた。", "煙草", "たばこ"),
            Case("樹皮の匂いが部屋に漂っていた。", "樹皮", "じゅひ"),
            Case("彼女は黙って頷いた。", "頷い", "うなずい"),
            Case("遠くで踏切の警報機が鳴っている。", "踏切", "ふみきり"),
            Case("僕は曖昧に微笑んだ。", "曖昧", "あいまい"),
            Case("僕は曖昧に微笑んだ。", "微笑ん", "ほほえん"),
            Case("古い井戸の底は湿っていた。", "井戸", "いど"),
            Case("彼は躊躇なくその扉を開けた。", "躊躇", "ちゅうちょ"),
            Case("彼は躊躇なくその扉を開けた。", "扉", "とびら"),
            Case("羊男は相槌を打ちながら耳を傾けた。", "相槌", "あいづち"),
            Case("羊男は相槌を打ちながら耳を傾けた。", "傾け", "かたむけ"),
            Case("椨（タブ）の樹皮・白檀・炭", "椨", "たぶのき"),
            Case("椨（タブ）の樹皮・白檀・炭", "白檀", "びゃくだん"),
        ]
        for c in cases {
            XCTAssertEqual(reading(of: c.word, in: c.sentence), c.reading, c.word)
        }
    }

    func testTheSameKanjiReadsByContext() {
        let sentence = "生地を生のまま食べる人生もある。"
        XCTAssertEqual(reading(of: "生地", in: sentence), "きじ")
        XCTAssertEqual(reading(of: "生", in: sentence), "なま")
        XCTAssertEqual(reading(of: "人生", in: sentence), "じんせい")
    }

    func testLongVowelsAndVoicedMarksSurviveTheRoundTrip() {
        XCTAssertEqual(reading(of: "遠く", in: "遠くで鳴っている。"), "とおく")
        XCTAssertEqual(reading(of: "警報", in: "警報機が鳴る。"), "けいほう")
        XCTAssertEqual(reading(of: "続け", in: "降り続けていた。"), "つづけ")
    }

    func testInflectionsAreCutFromTheirStem() {
        let surfaces = SystemTokenizer.tokens(in: "彼は黙って頷いた。").filter(\.isWord).map(\.surface)
        XCTAssertEqual(surfaces, ["彼", "は", "黙っ", "て", "頷い", "た"])
    }

    func testPunctuationIsKeptButIsNotAWord() {
        let tokens = SystemTokenizer.tokens(in: "「はい」と彼は言った。")
        XCTAssertEqual(tokens.map(\.surface).joined(), "「はい」と彼は言った。")
        XCTAssertEqual(tokens.filter { !$0.isWord }.map(\.surface), ["「", "」", "。"])
        XCTAssertEqual(tokens.first { $0.surface == "。" }?.reading, "。")
    }

    func testRangesPointBackIntoTheSentence() {
        let sentence = "樹皮の匂い"
        let tokens = SystemTokenizer.tokens(in: sentence)
        for token in tokens {
            XCTAssertEqual(String(sentence[token.range]), token.surface)
        }
    }
}
