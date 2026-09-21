import XCTest

@testable import YomidoriCore

final class SVGPathTests: XCTestCase {
    func testAKanjiVGStrokeReadsAsAbsoluteCurves() {
        let commands = SVGPath.commands(
            "M22.41,32.87c1.3,1.3,1.71,2.72,1.7,5.07C24,64.5,22,80.88,11.87,92.63")
        XCTAssertEqual(commands.count, 3)
        XCTAssertEqual(commands[0], .move(CGPoint(x: 22.41, y: 32.87)))
        guard case .curve(let end, let c1, let c2) = commands[1] else { return XCTFail("curve") }
        XCTAssertEqual(c1.x, 23.71, accuracy: 0.001)
        XCTAssertEqual(c2.y, 35.59, accuracy: 0.001)
        XCTAssertEqual(end.x, 24.11, accuracy: 0.001)
        XCTAssertEqual(end.y, 37.94, accuracy: 0.001)
        XCTAssertEqual(
            commands[2],
            .curve(
                to: CGPoint(x: 11.87, y: 92.63), control1: CGPoint(x: 24, y: 64.5),
                control2: CGPoint(x: 22, y: 80.88)))
    }

    func testPackedNumbersLinesAndShorthands() {
        let commands = SVGPath.commands("M10-5l5 5H20V10c0,0,10,0,10,10s10,10,10,0Q5 5 0 0T10 10z")
        XCTAssertEqual(commands[0], .move(CGPoint(x: 10, y: -5)))
        XCTAssertEqual(commands[1], .line(CGPoint(x: 15, y: 0)))
        XCTAssertEqual(commands[2], .line(CGPoint(x: 20, y: 0)))
        XCTAssertEqual(commands[3], .line(CGPoint(x: 20, y: 10)))
        XCTAssertEqual(
            commands[4],
            .curve(
                to: CGPoint(x: 30, y: 20), control1: CGPoint(x: 20, y: 10),
                control2: CGPoint(x: 30, y: 10)))
        // s mirrors the previous second control (30,10) through (30,20) to (30,30).
        XCTAssertEqual(
            commands[5],
            .curve(
                to: CGPoint(x: 40, y: 20), control1: CGPoint(x: 30, y: 30),
                control2: CGPoint(x: 40, y: 30)))
        XCTAssertEqual(commands[6], .quad(to: CGPoint(x: 0, y: 0), control: CGPoint(x: 5, y: 5)))
        XCTAssertEqual(
            commands[7], .quad(to: CGPoint(x: 10, y: 10), control: CGPoint(x: -5, y: -5)))
        XCTAssertEqual(commands[8], .close)
    }

    func testImplicitLinesAfterAMoveAndGarbageStops() {
        XCTAssertEqual(
            SVGPath.commands("M0 0 10 10 20 20"),
            [.move(.zero), .line(CGPoint(x: 10, y: 10)), .line(CGPoint(x: 20, y: 20))])
        XCTAssertEqual(SVGPath.commands("M0 0 A1"), [.move(.zero)])
        XCTAssertEqual(SVGPath.commands(""), [])
    }
}
