import XCTest

@testable import YomidoriCore

final class KanaTests: XCTestCase {
    func testKatakanaReadingBecomesHiragana() {
        XCTAssertEqual(Kana.hiragana("ヨミドリ"), "よみどり")
        XCTAssertEqual(Kana.hiragana("ブンチョウ"), "ぶんちょう")
    }

    func testHiraganaBecomesKatakana() {
        XCTAssertEqual(Kana.katakana("よみどり"), "ヨミドリ")
    }

    func testOtherScriptsAndTheLengthMarkPassThrough() {
        XCTAssertEqual(Kana.hiragana("読み鳥、Yomidori。"), "読み鳥、Yomidori。")
        XCTAssertEqual(Kana.hiragana("コーヒー"), "こーひー")
        XCTAssertEqual(Kana.hiragana("ヴァ"), "ゔぁ")
    }

    func testRoundTrip() {
        let reading = "シルバーブンチョウ"
        XCTAssertEqual(Kana.katakana(Kana.hiragana(reading)), reading)
    }

    func testIsKana() {
        XCTAssertTrue(Kana.isKana("よみどり"))
        XCTAssertTrue(Kana.isKana("ヨミドリー"))
        XCTAssertFalse(Kana.isKana("読み鳥"))
        XCTAssertFalse(Kana.isKana(""))
    }
}
