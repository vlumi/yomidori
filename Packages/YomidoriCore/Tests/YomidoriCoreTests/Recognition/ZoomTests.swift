import XCTest

@testable import YomidoriCore

final class ZoomTests: XCTestCase {
    private let bounds = CGSize(width: 400, height: 400)

    func testAStillOpensFillingTheWidthWithItsTopInView() {
        // A 3000×4000 still fits 300×400 here; filling the width scales it by four thirds and
        // pushes it down by half the growth, so the top edge stays at the top.
        let zoom = Zoom.fillingWidth(of: CGSize(width: 3000, height: 4000), in: bounds)
        XCTAssertEqual(zoom.scale, 4.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(zoom.offset.width, 0)
        XCTAssertEqual(zoom.offset.height, 400 / 6, accuracy: 0.01)
        XCTAssertEqual(Zoom.fillingWidth(of: .zero, in: bounds), Zoom())
    }

    func testSteppingClampsTheScaleAndKeepsThePanInside() {
        let far = Zoom(scale: 5, offset: CGSize(width: 100, height: 0))
        let closer = far.stepped(by: 1.6, in: bounds)
        XCTAssertEqual(closer.scale, 6)
        XCTAssertEqual(closer.offset.width, 120, accuracy: 0.0001)
        let back = closer.stepped(by: 0.1, in: bounds)
        XCTAssertEqual(back, Zoom())
    }

    func testClampingKeepsThePanWithinTheSlack() {
        let zoom = Zoom(scale: 2, offset: CGSize(width: 900, height: -900)).clamped(in: bounds)
        XCTAssertEqual(zoom.offset, CGSize(width: 200, height: -200))
    }
}
