import CoreGraphics
import XCTest

@testable import YomidoriCore

final class SpreadLayoutTests: XCTestCase {
    func testTheNextPageGoesLeftOfColumnsAndUnderRows() {
        XCTAssertEqual(SpreadLayout.side(forVertical: true), .left)
        XCTAssertEqual(SpreadLayout.side(forVertical: false), .below)
        let column = RecognizedLine(
            text: "樹皮の匂い", box: CGRect(x: 0.8, y: 0.2, width: 0.1, height: 0.6), confidence: 1)
        let row = RecognizedLine(
            text: "第五章", box: CGRect(x: 0.1, y: 0.9, width: 0.3, height: 0.05), confidence: 1)
        XCTAssertTrue(SpreadLayout.isVertical([column, row]))
        XCTAssertFalse(SpreadLayout.isVertical([row]))
        XCTAssertFalse(SpreadLayout.isVertical([]))
    }

    func testSideBySideTheFirstPageIsOnTheRightForColumns() {
        // A tall page and a shorter one: both at the tall one's height.
        let sizes = [CGSize(width: 300, height: 400), CGSize(width: 150, height: 200)]
        let left = SpreadLayout.arrange(sizes, nextOn: .left)
        XCTAssertEqual(left.size, CGSize(width: 600, height: 400))
        XCTAssertEqual(left.frames[0], CGRect(x: 300, y: 0, width: 300, height: 400))
        XCTAssertEqual(left.frames[1], CGRect(x: 0, y: 0, width: 300, height: 400))
        let right = SpreadLayout.arrange(sizes, nextOn: .right)
        XCTAssertEqual(right.frames[0], CGRect(x: 0, y: 0, width: 300, height: 400))
        XCTAssertEqual(right.frames[1], CGRect(x: 300, y: 0, width: 300, height: 400))
    }

    func testOneUnderAnotherAtTheWidestWidth() {
        let sizes = [CGSize(width: 400, height: 300), CGSize(width: 200, height: 100)]
        let below = SpreadLayout.arrange(sizes, nextOn: .below)
        XCTAssertEqual(below.size, CGSize(width: 400, height: 500))
        XCTAssertEqual(below.frames[1], CGRect(x: 0, y: 300, width: 400, height: 200))
        XCTAssertEqual(SpreadLayout.arrange([], nextOn: .left).frames, [])
        XCTAssertEqual(SpreadLayout.arrange([.zero], nextOn: .left).frames, [])
    }

    func testFittedIntoAViewAndHitByATap() {
        let sizes = [CGSize(width: 300, height: 400), CGSize(width: 300, height: 400)]
        let frames = SpreadLayout.fitted(sizes, nextOn: .left, in: CGSize(width: 300, height: 400))
        // The 600 × 400 sheet fits the width: half scale, centered vertically.
        XCTAssertEqual(frames[0], CGRect(x: 150, y: 100, width: 150, height: 200))
        XCTAssertEqual(frames[1], CGRect(x: 0, y: 100, width: 150, height: 200))
        XCTAssertEqual(SpreadLayout.page(at: CGPoint(x: 200, y: 200), in: frames), 0)
        XCTAssertEqual(SpreadLayout.page(at: CGPoint(x: 20, y: 200), in: frames), 1)
        // Above the sheet: the nearest page.
        XCTAssertEqual(SpreadLayout.page(at: CGPoint(x: 20, y: 10), in: frames), 1)
        XCTAssertNil(SpreadLayout.page(at: .zero, in: []))
    }
}
