import XCTest

@testable import YomidoriCore

final class DrawerDetentsTests: XCTestCase {
    func testTheDrawerSettlesAtTheNearestDetent() {
        XCTAssertEqual(DrawerDetents.nearest(0.3), 0.2)
        XCTAssertEqual(DrawerDetents.nearest(0.36), 0.5)
        XCTAssertEqual(DrawerDetents.nearest(0.9), 0.8)
    }

    func testTheHeightHasAFloor() {
        XCTAssertEqual(DrawerDetents.height(fraction: 0.2, screenHeight: 800), 180)
        XCTAssertEqual(DrawerDetents.height(fraction: 0.5, screenHeight: 800), 400)
    }

    func testADragMovesTheFractionAgainstTheFingerWithinTheRange() {
        XCTAssertEqual(DrawerDetents.dragged(from: 0.5, by: -80, screenHeight: 800), 0.6)
        XCTAssertEqual(DrawerDetents.dragged(from: 0.5, by: 800, screenHeight: 800), 0.2)
        XCTAssertEqual(DrawerDetents.dragged(from: 0.5, by: -800, screenHeight: 800), 0.8)
    }

    func testADoubleTapGoesToTheLargestAndBackToWhereItStood() {
        let up = DrawerDetents.toggled(from: 0.5, remembered: nil)
        XCTAssertEqual(up.settle, 0.8)
        XCTAssertEqual(up.remember, 0.5)
        let back = DrawerDetents.toggled(from: 0.8, remembered: 0.5)
        XCTAssertEqual(back.settle, 0.5)
        XCTAssertNil(back.remember)
        // Opened to the largest by hand, with nothing remembered: back to the smallest.
        XCTAssertEqual(DrawerDetents.toggled(from: 0.8, remembered: nil).settle, 0.2)
    }
}
