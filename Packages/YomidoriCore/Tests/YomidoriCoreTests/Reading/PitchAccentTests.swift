import XCTest

@testable import YomidoriCore

final class PitchAccentTests: XCTestCase {
    func testEveryPatternOfAReading() {
        XCTAssertEqual(PitchAccent.patterns(forMoraCount: 2).map(\.downstep), [0, 1, 2])
        XCTAssertEqual(PitchAccent.patterns(forMoraCount: 0).map(\.downstep), [0, 1])
    }

    func testMoraeJoinSmallKanaAndKeepTheRest() {
        XCTAssertEqual(PitchAccent.morae(of: "じゅひ"), ["じゅ", "ひ"])
        XCTAssertEqual(PitchAccent.morae(of: "ちゅうちょ"), ["ちゅ", "う", "ちょ"])
        XCTAssertEqual(PitchAccent.morae(of: "うなずく"), ["う", "な", "ず", "く"])
        XCTAssertEqual(PitchAccent.morae(of: "ぶんちょう"), ["ぶ", "ん", "ちょ", "う"])
        XCTAssertEqual(PitchAccent.morae(of: "コーヒー"), ["コ", "ー", "ヒ", "ー"])
        XCTAssertEqual(PitchAccent.morae(of: "きって"), ["き", "っ", "て"])
    }

    func testTheThreeShapes() {
        // 鼻 はな [0]: low then high, and it stays high.
        XCTAssertEqual(PitchAccent(downstep: 0).highs(forMoraCount: 2), [false, true])
        // 雨 あめ [1]: high then low.
        XCTAssertEqual(PitchAccent(downstep: 1).highs(forMoraCount: 2), [true, false])
        // 頷く うなずく [3]: low, high, high, low.
        XCTAssertEqual(PitchAccent(downstep: 3).highs(forMoraCount: 4), [false, true, true, false])
        // 花 はな [2]: the drop after the last mora is the particle's to show.
        XCTAssertEqual(PitchAccent(downstep: 2).highs(forMoraCount: 2), [false, true])
    }
}
