import CoreGraphics
import Foundation
import YomidoriCore

/// Upright, with any EXIF orientation baked into the pixels. The screen gets a copy drawn
/// down to a size it can show at once: a 48-megapixel frame put straight into an image view
/// holds the main thread for seconds while it is copied for the display, which is what made
/// the app seem to hang after the shutter. The recognizers read the full frame.
public struct Still: Identifiable {
    public let id: UUID
    public let image: CGImage
    /// The picture for the screen, no longer than `previewSide` on its long side; the full
    /// one where it is no larger than that. The same shape, so what is drawn over it by
    /// normalized coordinates lands where it should.
    public let preview: CGImage

    /// Four times a phone's width in pixels: room for the zoom a page of print wants, and
    /// finer boxes for Live Text, which reads this copy and draws its highlights from them.
    public static let previewSide = 4096

    public var size: CGSize {
        CGSize(width: image.width, height: image.height)
    }

    /// Both made already, as the camera makes them from the frame in one pass.
    public init(image: CGImage, preview: CGImage) {
        id = UUID()
        self.image = image
        self.preview = preview
    }

    private init(id: UUID, image: CGImage, preview: CGImage) {
        self.id = id
        self.image = image
        self.preview = preview
    }

    /// The same still, the full frame let go once both recognizers have read it: the screen
    /// shows the preview, and a spread of two 48-megapixel frames is a quarter of a gigabyte.
    public func lightened() -> Still {
        Still(id: id, image: preview, preview: preview)
    }

    /// Decoded off the main thread, which a 48-megapixel HEIC held for a second or two,
    /// and handed over on it. Nothing for data that is no image.
    public static func decode(_ data: Data, then take: @escaping @MainActor (Still) -> Void) {
        Task.detached(priority: .userInitiated) {
            guard let still = Still(data: data) else { return }
            await take(still)
        }
    }

    /// The same for a file on this machine, read under its security scope.
    public static func decode(file url: URL, then take: @escaping @MainActor (Still) -> Void) {
        Task.detached(priority: .userInitiated) {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            guard let still = Still(file: url) else { return }
            await take(still)
        }
    }

    /// Made where the frame is: off the main thread, which the drawing down would hold.
    public init(image: CGImage) {
        id = UUID()
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
