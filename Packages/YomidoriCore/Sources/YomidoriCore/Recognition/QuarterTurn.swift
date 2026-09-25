import CoreGraphics
import Foundation

/// An image turned by whole quarters, clockwise as it is looked at: a camera frame taken the
/// way the output delivers it, turned after to the way the phone was held, so the camera's
/// own pipeline is never reconfigured between shots.
public enum QuarterTurn {
    /// `degrees` clockwise, rounded to a quarter; the image itself for none.
    public static func rotate(_ image: CGImage, clockwise degrees: CGFloat) -> CGImage? {
        let quarters = ((Int((degrees / 90).rounded()) % 4) + 4) % 4
        guard quarters != 0 else { return image }
        let width = image.width
        let height = image.height
        let (outWidth, outHeight) = quarters % 2 == 0 ? (width, height) : (height, width)
        guard
            let context = CGContext(
                data: nil, width: outWidth, height: outHeight, bitsPerComponent: 8,
                bytesPerRow: 0, space: image.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                    | CGBitmapInfo.byteOrder32Little.rawValue)
        else { return nil }
        // Core Graphics turns counterclockwise with y up: about the centre, then drawn back.
        context.translateBy(x: CGFloat(outWidth) / 2, y: CGFloat(outHeight) / 2)
        context.rotate(by: -CGFloat(quarters) * .pi / 2)
        context.draw(
            image,
            in: CGRect(
                x: -CGFloat(width) / 2, y: -CGFloat(height) / 2, width: CGFloat(width),
                height: CGFloat(height)))
        return context.makeImage()
    }
}
