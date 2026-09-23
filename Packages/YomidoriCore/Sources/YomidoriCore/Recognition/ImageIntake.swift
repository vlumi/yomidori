import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// An image from outside the app (the photo library, a cover from another device) decoded
/// with care: only real image data, of a bounded size, its pixel count read from the header
/// before anything is decoded, and drawn upright at no more than `longestSide`.
public enum ImageIntake {
    /// A 48-megapixel camera frame, and room above it.
    public static let mostPixels = 100_000_000
    public static let largestFile = 60_000_000

    public static func image(from data: Data, longestSide: Int) -> CGImage? {
        guard data.count <= largestFile,
            let source = CGImageSourceCreateWithData(data as CFData, nil)
        else { return nil }
        return image(from: source, longestSide: longestSide)
    }

    public static func image(at url: URL, longestSide: Int) -> CGImage? {
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
            size <= largestFile,
            let source = CGImageSourceCreateWithURL(url as CFURL, nil)
        else { return nil }
        return image(from: source, longestSide: longestSide)
    }

    private static func image(from source: CGImageSource, longestSide: Int) -> CGImage? {
        guard let type = CGImageSourceGetType(source).map({ UTType($0 as String) }),
            type?.conforms(to: .image) == true,
            CGImageSourceGetCount(source) >= 1,
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int,
            width > 0, height > 0, width <= mostPixels / height
        else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: min(longestSide, max(width, height)),
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
