import CoreGraphics
import Foundation
import YomidoriCore

/// Upright, with any EXIF orientation baked into the pixels.
public struct Still: Identifiable {
    public let id = UUID()
    public let image: CGImage

    public var size: CGSize {
        CGSize(width: image.width, height: image.height)
    }

    public init(image: CGImage) {
        self.image = image
    }

    /// The longest side a still is kept at: a 48-megapixel frame's, so the camera loses nothing.
    public static let longestSide = 8_064

    /// A picture file on this machine, read only as far as its size and header say it is one:
    /// a web address is not a file, however it came to be on the pasteboard or dropped.
    public init?(file url: URL) {
        guard url.isFileURL,
            let image = ImageIntake.image(at: url, longestSide: Self.longestSide)
        else { return nil }
        self.image = image
    }

    /// Nil for data that is not an image, or one too large to be a photo; decoded upright.
    public init?(data: Data) {
        guard let image = ImageIntake.image(from: data, longestSide: Self.longestSide) else {
            return nil
        }
        self.image = image
    }
}
