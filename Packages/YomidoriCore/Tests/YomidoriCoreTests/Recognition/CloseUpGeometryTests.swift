import XCTest

@testable import YomidoriCore

final class CloseUpGeometryTests: XCTestCase {
    private let image = CGSize(width: 3000, height: 4000)
    private let frame = CGRect(x: 0, y: 162, width: 390, height: 520)

    func testOnALineTheCropIsTheLineAndTheWindowAFewCharacters() throws {
        // A line across the middle of the page, 120 px tall in image pixels.
        let line = RecognizedLine(
            text: "樹皮の匂いが部屋に漂っていた。", box: CGRect(x: 0.1, y: 0.5, width: 0.8, height: 0.03),
            confidence: 1)
        let tap = CGPoint(x: 195, y: 162 + 520 * 0.485)
        let geometry = try XCTUnwrap(
            CloseUpGeometry(tap: tap, in: frame, lines: [line], imageSize: image))
        XCTAssertEqual(geometry.crop.height, 120 + 2 * 96, accuracy: 0.5)
        XCTAssertEqual(geometry.crop.minX, 300 - 96, accuracy: 0.5)
        XCTAssertEqual(geometry.window.width, 8 * 120 + 2 * 60, accuracy: 0.5)
        XCTAssertTrue(geometry.crop.contains(CGPoint(x: 1500, y: 2000)))
    }

    func testOffAnyLineASquareAndAColumnStandIn() throws {
        let geometry = try XCTUnwrap(
            CloseUpGeometry(tap: CGPoint(x: 195, y: 422), in: frame, lines: [], imageSize: image))
        XCTAssertEqual(geometry.crop.width, 4000 / 3, accuracy: 0.5)
        XCTAssertEqual(geometry.window.width, 4000 / 12, accuracy: 0.5)
        XCTAssertEqual(geometry.window.height, geometry.crop.height, accuracy: 0.5)
    }

    func testATapOutsideTheStillIsNothing() {
        XCTAssertNil(
            CloseUpGeometry(tap: CGPoint(x: 10, y: 10), in: frame, lines: [], imageSize: image))
    }
}
