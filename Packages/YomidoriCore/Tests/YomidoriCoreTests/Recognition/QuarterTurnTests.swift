import CoreGraphics
import XCTest

@testable import YomidoriCore

final class QuarterTurnTests: XCTestCase {
    /// Two pixels side by side, as looked at: red on the left, blue on the right.
    private func redThenBlue() -> CGImage {
        let context = CGContext(
            data: nil, width: 2, height: 1, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        context.setFillColor(red: 0, green: 0, blue: 1, alpha: 1)
        context.fill(CGRect(x: 1, y: 0, width: 1, height: 1))
        return context.makeImage()!
    }

    /// Each pixel from the top left, row by row, as "r" or "b".
    private func pixels(_ image: CGImage) -> [String] {
        let context = CGContext(
            data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
            bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let data = context.data!.assumingMemoryBound(to: UInt8.self)
        return (0..<(image.width * image.height)).map { data[$0 * 4] > 128 ? "r" : "b" }
    }

    func testAQuarterClockwisePutsTheLeftOnTop() throws {
        let turned = try XCTUnwrap(QuarterTurn.rotate(redThenBlue(), clockwise: 90))
        XCTAssertEqual([turned.width, turned.height], [1, 2])
        XCTAssertEqual(pixels(turned), ["r", "b"])
    }

    func testOtherTurns() throws {
        let image = redThenBlue()
        XCTAssertEqual(pixels(image), ["r", "b"])
        XCTAssertTrue(QuarterTurn.rotate(image, clockwise: 0) === image)
        XCTAssertTrue(QuarterTurn.rotate(image, clockwise: 360) === image)
        XCTAssertEqual(
            pixels(try XCTUnwrap(QuarterTurn.rotate(image, clockwise: 180))), ["b", "r"])
        XCTAssertEqual(
            pixels(try XCTUnwrap(QuarterTurn.rotate(image, clockwise: 270))), ["b", "r"])
        XCTAssertEqual(
            pixels(try XCTUnwrap(QuarterTurn.rotate(image, clockwise: -90))), ["b", "r"])
    }
}
