import XCTest

@testable import YomidoriCore

final class PitchPhraseTests: XCTestCase {
    func testAnEstimateIsReadPhraseByPhrase() {
        XCTAssertEqual(
            PitchPhrase.parse("けんとうが:3|つく:1"),
            [PitchPhrase(reading: "けんとうが", downstep: 3), PitchPhrase(reading: "つく", downstep: 1)])
        XCTAssertEqual(
            PitchPhrase.parse("どくしょかんそうぶん:0"),
            [PitchPhrase(reading: "どくしょかんそうぶん", downstep: 0)])
        XCTAssertEqual(PitchPhrase.parse("きょう:1").first?.accent, PitchAccent(downstep: 1))
    }

    func testAnythingElseIsNoEstimate() {
        XCTAssertEqual(PitchPhrase.parse(""), [])
        XCTAssertEqual(PitchPhrase.parse("けんとうが"), [])
        XCTAssertEqual(PitchPhrase.parse("けんとうが:x"), [])
        XCTAssertEqual(PitchPhrase.parse(":2"), [])
        XCTAssertEqual(PitchPhrase.parse("つく:-1"), [])
        // A drop past the phrase's last mora: きょ and う are two.
        XCTAssertEqual(PitchPhrase.parse("きょう:3"), [])
        XCTAssertEqual(PitchPhrase.parse("つく:1|"), [])
    }
}
