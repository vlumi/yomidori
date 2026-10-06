import CoreGraphics
import Foundation
import YomidoriCore

/// Upright, with any EXIF orientation baked into the pixels. The screen gets a copy drawn
/// down to a size it can show at once: a 48-megapixel frame put straight into an image view
/// holds the main thread for seconds while it is copied for the display, which is what made
/// the app seem to hang after the shutter. The recognizers read the full frame.
public struct Still: Identifiable {
    public let id = UUID()
    public let image: CGImage
    /// The picture for the screen, no longer than `previewSide` on its long side; the full
    /// one where it is no larger than that. The same shape, so what is drawn over it by
    /// normalized coordinates lands where it should.
    public let preview: CGImage

    /// Three times a phone's width in pixels, room for the zoom a page of print wants.
    public static let previewSide = 3072

    public var size: CGSize {
        CGSize(width: image.width, height: image.height)
    }

    /// Both made already, as the camera makes them from the frame in one pass.
    public init(image: CGImage, preview: CGImage) {
        self.image = image
        self.preview = preview
    }

    /// Made where the frame is: off the main thread, which the drawing down would hold.
    public init(image: CGImage) {
        self.image = image
        let longest = max(image.width, image.height)
        preview =
            longest > Self.previewSide
            ? image.scaled(by: CGFloat(Self.previewSide) / CGFloat(longest)) ?? image : image
    }

    /// The longest side a still is kept at: a 48-megapixel frame's, so the camera loses nothing.
    public static let longestSide = 8_064

    /// A picture file on this machine, read only as far as its size and header say it is one:
    /// a web address is not a file, however it came to be on the pasteboard or dropped.
    public init?(file url: URL) {
        guard url.isFileURL,
            let image = ImageIntake.image(at: url, longestSide: Self.longestSide)
        else { return nil }
        self.init(image: image)
    }

    /// Nil for data that is not an image, or one too large to be a photo; decoded upright.
    public init?(data: Data) {
        guard let image = ImageIntake.image(from: data, longestSide: Self.longestSide) else {
            return nil
        }
        self.init(image: image)
    }
}
