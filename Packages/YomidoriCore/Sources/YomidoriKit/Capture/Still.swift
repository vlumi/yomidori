import CoreGraphics
import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// A frozen frame: the image everything after the shutter works on. Upright,
/// with any EXIF orientation baked into the pixels, so the recognizer and the
/// screen agree on which way is up without either knowing about orientation.
public struct Still: Identifiable {
    public let id = UUID()
    public let image: CGImage

    public var size: CGSize {
        CGSize(width: image.width, height: image.height)
    }

    /// The pixels inside `rect` (image coordinates, y down) as a still of their own,
    /// at full resolution: what the recognizer gets when it reads up close.
    public func cropped(to rect: CGRect) -> Still? {
        image.cropping(to: rect).map(Still.init(image:))
    }

    /// An image already upright, as a screenshot taken in-app or a test fixture is.
    public init(image: CGImage) {
        self.image = image
    }

    /// Decodes a photo's JPEG or HEIC, or a screenshot's PNG. Nil for data that is
    /// not an image, and wherever there is no UIKit to decode with (the macOS test
    /// build), which has no camera and no picker to feed it anyway.
    public init?(data: Data) {
        #if canImport(UIKit)
        guard let decoded = UIImage(data: data), let upright = Self.upright(decoded) else {
            return nil
        }
        image = upright
        #else
        return nil
        #endif
    }

    #if canImport(UIKit)
    private static func upright(_ image: UIImage) -> CGImage? {
        if image.imageOrientation == .up {
            return image.cgImage
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: image.size, format: format)
            .image { _ in image.draw(in: CGRect(origin: .zero, size: image.size)) }
            .cgImage
    }
    #endif
}
