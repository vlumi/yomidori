import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import YomidoriCore

/// Collection covers as JPEGs beside the stores, one per id, small enough to sync.
enum CoverArchive {
    static let longestSide: CGFloat = 600

    static func directory() throws -> URL {
        let directory = try Cards.directory().appendingPathComponent("Covers", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func url(for id: UUID) throws -> URL {
        try directory().appendingPathComponent("\(id.uuidString).jpg")
    }

    @discardableResult
    static func save(_ image: CGImage, as id: UUID = UUID()) throws -> UUID {
        let destination = try url(for: id)
        guard
            let sink = CGImageDestinationCreateWithURL(
                destination as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
        else { throw CocoaError(.fileWriteUnknown) }
        let scale = min(1, longestSide / CGFloat(max(image.width, image.height)))
        let scaled = scale < 1 ? Self.scaled(image, by: scale) ?? image : image
        CGImageDestinationAddImage(
            sink, scaled, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
        guard CGImageDestinationFinalize(sink) else { throw CocoaError(.fileWriteUnknown) }
        return id
    }

    static func load(_ id: UUID) -> CGImage? {
        guard let url = try? url(for: id) else { return nil }
        return image(at: url)
    }

    static func remove(_ ids: [UUID]) {
        for id in ids {
            if let url = try? url(for: id) {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    /// Covers and page photos once shared a Stills folder, at two thousand pixels; the covers
    /// move here, scaled down, and the folder goes with every page photo in it.
    static func migrate(covers: [UUID]) {
        guard
            let stills = try? Cards.directory().appendingPathComponent("Stills", isDirectory: true),
            FileManager.default.fileExists(atPath: stills.path)
        else { return }
        for id in covers {
            let old = stills.appendingPathComponent("\(id.uuidString).jpg")
            if let image = image(at: old) {
                _ = try? save(image, as: id)
            }
        }
        try? FileManager.default.removeItem(at: stills)
    }

    private static func image(at url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private static func scaled(_ image: CGImage, by scale: CGFloat) -> CGImage? {
        let width = Int(CGFloat(image.width) * scale)
        let height = Int(CGFloat(image.height) * scale)
        guard
            let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}
