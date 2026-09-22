import XCTest

@testable import YomidoriCore

/// The stems the tokenizer fixture actually produces, back to the forms JMdict lists.
final class DeinflectorTests: XCTestCase {
    private func assertCandidates(_ surface: String, include form: String) {
        XCTAssertTrue(Deinflector.candidates(for: surface).contains(form), "\(surface) → \(form)")
    }

    func testTheWordItselfComesFirst() {
        XCTAssertEqual(Deinflector.candidates(for: "樹皮").first, "樹皮")
        XCTAssertEqual(Deinflector.candidates(for: "食べる").first, "食べる")
        XCTAssertEqual(Deinflector.candidates(for: "の"), ["の"])
    }

    func testGodanStems() {
        assertCandidates("頷い", include: "頷く")
        assertCandidates("漂っ", include: "漂う")
        assertCandidates("黙っ", include: "黙る")
        assertCandidates("湿っ", include: "湿る")
        assertCandidates("待っ", include: "待つ")
        assertCandidates("微笑ん", include: "微笑む")
        assertCandidates("飛ん", include: "飛ぶ")
        assertCandidates("指し", include: "指す")
        assertCandidates("打ち", include: "打つ")
        assertCandidates("鳴っ", include: "鳴る")
        assertCandidates("いっ", include: "いく")
    }

    func testIchidanStems() {
        assertCandidates("点け", include: "点ける")
        assertCandidates("続け", include: "続ける")
        assertCandidates("傾け", include: "傾ける")
        assertCandidates("開け", include: "開ける")
        assertCandidates("食べ", include: "食べる")
        assertCandidates("起き", include: "起きる")
    }

    func testAmbiguousStemsOfferEveryRow() {
        let forms = Deinflector.candidates(for: "降り")
        XCTAssertTrue(forms.contains("降る"))
        XCTAssertTrue(forms.contains("降りる"))
    }

    func testPotentialStemsReachTheGodanVerb() {
        assertCandidates("負え", include: "負う")
        assertCandidates("負え", include: "負える")
        assertCandidates("読め", include: "読む")
        assertCandidates("書け", include: "書く")
        assertCandidates("待て", include: "待つ")
    }

    func testPassiveAndNegativeStems() {
        assertCandidates("照らさ", include: "照らす")
        assertCandidates("書か", include: "書く")
        assertCandidates("読ま", include: "読む")
        assertCandidates("言わ", include: "言う")
        assertCandidates("待た", include: "待つ")
    }

    func testSuruVerbsAndAdjectives() {
        assertCandidates("存在し", include: "存在する")
        assertCandidates("古く", include: "古い")
        assertCandidates("寒か", include: "寒い")
    }
}
