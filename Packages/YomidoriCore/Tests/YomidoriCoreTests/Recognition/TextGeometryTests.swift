import XCTest

@testable import YomidoriCore

final class TextGeometryTests: XCTestCase {
    // An iPhone-shaped view; a 3:4 photo fits its width, a 4:3 one leaves bands.
    private let bounds = CGSize(width: 390, height: 844)

    func testPortraitPhotoFitsTheWidth() {
        let frame = TextGeometry.fittedFrame(of: CGSize(width: 3000, height: 4000), in: bounds)
        XCTAssertEqual(frame, CGRect(x: 0, y: 162, width: 390, height: 520))
    }

    func testLandscapePhotoIsCenteredBetweenBands() {
        let frame = TextGeometry.fittedFrame(of: CGSize(width: 4000, height: 3000), in: bounds)
        XCTAssertEqual(frame.minX, 0)
        XCTAssertEqual(frame.width, 390)
        XCTAssertEqual(frame.height, 292.5)
        XCTAssertEqual(frame.midY, bounds.height / 2)
    }

    func testEmptySizesGiveNoFrame() {
        XCTAssertEqual(TextGeometry.fittedFrame(of: .zero, in: bounds), .zero)
        XCTAssertEqual(TextGeometry.fittedFrame(of: CGSize(width: 1, height: 1), in: .zero), .zero)
    }

    func testViewRectFlipsYAndScales() {
        let frame = CGRect(x: 0, y: 162, width: 390, height: 520)
        // A box at the top-left corner of the image lands at the top-left of the frame.
        let top = TextGeometry.viewRect(
            for: CGRect(x: 0, y: 0.9, width: 0.1, height: 0.1), in: frame)
        XCTAssertEqual(top, CGRect(x: 0, y: 162, width: 39, height: 52))
        // A box near the bottom-right of the image lands near the bottom-right of the frame.
        let bottom = TextGeometry.viewRect(
            for: CGRect(x: 0.5, y: 0.05, width: 0.25, height: 0.1), in: frame)
        XCTAssertEqual(bottom.minX, 195)
        XCTAssertEqual(bottom.maxY, 162 + 520 - 26)
        XCTAssertEqual(bottom.width, 97.5)
    }

    func testTapMapsToAnImagePixel() {
        let frame = CGRect(x: 0, y: 162, width: 390, height: 520)
        let image = CGSize(width: 3000, height: 4000)
        // The frame's top-left is the image's first pixel; its centre is the image's centre.
        XCTAssertEqual(
            TextGeometry.imagePoint(at: CGPoint(x: 0, y: 162), in: frame, imageSize: image), .zero)
        XCTAssertEqual(
            TextGeometry.imagePoint(at: CGPoint(x: 195, y: 422), in: frame, imageSize: image),
            CGPoint(x: 1500, y: 2000))
        XCTAssertNil(
            TextGeometry.imagePoint(at: CGPoint(x: 10, y: 10), in: frame, imageSize: image))
    }

    func testCropStaysInsideTheImage() {
        let image = CGSize(width: 3000, height: 4000)
        XCTAssertEqual(
            TextGeometry.cropRect(around: CGPoint(x: 1500, y: 2000), side: 1000, in: image),
            CGRect(x: 1000, y: 1500, width: 1000, height: 1000))
        // Near a corner the square slides in rather than shrinking.
        XCTAssertEqual(
            TextGeometry.cropRect(around: CGPoint(x: 100, y: 3950), side: 1000, in: image),
            CGRect(x: 0, y: 3000, width: 1000, height: 1000))
        // A screenshot narrower than the square gives the full width.
        XCTAssertEqual(
            TextGeometry.cropRect(
                around: CGPoint(x: 300, y: 300), side: 1000, in: CGSize(width: 800, height: 2000)),
            CGRect(x: 0, y: 0, width: 800, height: 1000))
    }

    func testImageRectBecomesANormalizedBoxAndBack() {
        let image = CGSize(width: 3000, height: 4000)
        let crop = CGRect(x: 0, y: 3000, width: 1000, height: 1000)
        let box = TextGeometry.normalizedBox(for: crop, imageSize: image)
        // The bottom-left corner of the image, in y-up terms.
        XCTAssertEqual(box, CGRect(x: 0, y: 0, width: 1 / 3, height: 0.25))
        let frame = CGRect(x: 0, y: 162, width: 390, height: 520)
        XCTAssertEqual(TextGeometry.viewRect(for: box, in: frame).maxY, frame.maxY)
    }

    func testTapPicksTheSmallestLineUnderIt() {
        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        // A tall column and a short line that sits inside the column's box.
        let column = RecognizedLine(
            text: "僕は彼女の顔を見た", box: CGRect(x: 0.8, y: 0.1, width: 0.1, height: 0.8),
            confidence: 1)
        let short = RecognizedLine(
            text: "顔", box: CGRect(x: 0.8, y: 0.4, width: 0.1, height: 0.1), confidence: 1)
        let lines = [column, short]

        XCTAssertEqual(
            TextGeometry.lineIndex(at: CGPoint(x: 85, y: 55), in: frame, lines: lines), 1)
        XCTAssertEqual(
            TextGeometry.lineIndex(at: CGPoint(x: 85, y: 20), in: frame, lines: lines), 0)
        XCTAssertNil(TextGeometry.lineIndex(at: CGPoint(x: 10, y: 50), in: frame, lines: lines))
        XCTAssertNil(TextGeometry.lineIndex(at: CGPoint(x: 85, y: 55), in: frame, lines: []))
    }
}
