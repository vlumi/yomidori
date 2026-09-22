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
}
