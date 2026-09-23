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

    /// `rect` in image coordinates, y down; at full resolution.
    public func cropped(to rect: CGRect) -> Still? {
        image.cropping(to: rect).map(Still.init(image:))
    }

    public init(image: CGImage) {
        self.image = image
    }

    /// The longest side a still is kept at: a 48-megapixel frame's, so the camera loses nothing.
    public static let longestSide = 8_064

    /// Nil for data that is not an image, or one too large to be a photo; decoded upright.
    public init?(data: Data) {
        guard let image = ImageIntake.image(from: data, longestSide: Self.longestSide) else {
            return nil
        }
        self.image = image
    }
}
