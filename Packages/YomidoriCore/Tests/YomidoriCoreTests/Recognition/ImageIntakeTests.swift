import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest

@testable import YomidoriCore

final class ImageIntakeTests: XCTestCase {
    private func png(width: Int, height: Int, orientation: Int? = nil, type: UTType = .png) -> Data
    {
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )!
        context.setFillColor(CGColor(red: 0.9, green: 0.9, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let data = NSMutableData()
        let sink = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil)!
        var properties: [CFString: Any] = [:]
        if let orientation { properties[kCGImagePropertyOrientation] = orientation }
        CGImageDestinationAddImage(sink, context.makeImage()!, properties as CFDictionary)
        CGImageDestinationFinalize(sink)
        return data as Data
    }

    func testAnImageIsDecodedScaledAndUpright() throws {
        let image = try XCTUnwrap(
            ImageIntake.image(from: png(width: 1200, height: 800), longestSide: 600))
        XCTAssertEqual(image.width, 600)
        XCTAssertEqual(image.height, 400)
        let small = try XCTUnwrap(
            ImageIntake.image(from: png(width: 300, height: 200), longestSide: 600))
        XCTAssertEqual(small.width, 300)
        // A camera JPEG held sideways says so in its orientation; it comes out upright.
        let turned = try XCTUnwrap(
            ImageIntake.image(
                from: png(width: 400, height: 300, orientation: 6, type: .jpeg), longestSide: 1000))
        XCTAssertEqual(turned.width, 300)
        XCTAssertEqual(turned.height, 400)
    }

    func testWhatIsNotAnImageOrIsTooLargeIsRefused() {
        XCTAssertNil(ImageIntake.image(from: Data("樹皮の匂い".utf8), longestSide: 600))
        XCTAssertNil(ImageIntake.image(from: Data(), longestSide: 600))
        XCTAssertNil(
            ImageIntake.image(from: Data(count: ImageIntake.largestFile + 1), longestSide: 600))
    }
}
