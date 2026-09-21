import CoreGraphics
import Foundation

#if canImport(UIKit)
import UIKit
#endif

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

    /// Nil for data that is not an image, and off iOS, where there is no UIKit to decode with.
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
