import XCTest

@testable import YomidoriCore

final class CoverLinesTests: XCTestCase {
    private func line(_ text: String, height: CGFloat) -> RecognizedLine {
        RecognizedLine(
            text: text, box: CGRect(x: 0.1, y: 0.5, width: 0.8, height: height), confidence: 1)
    }

    func testVisionsTallestLineLeadsAndLiveTextFillsIn() {
        let vision = [line("村上春樹", height: 0.03), line("羊をめぐる冒険", height: 0.08)]
        let merged = CoverLines.merge(
            vision: vision, liveText: "羊をめぐる冒険\n 講談社文庫 \n村上春樹\n\n")
        XCTAssertEqual(merged, ["羊をめぐる冒険", "村上春樹", "講談社文庫"])
        XCTAssertEqual(CoverLines.merge(vision: [], liveText: nil), [])
    }
}
