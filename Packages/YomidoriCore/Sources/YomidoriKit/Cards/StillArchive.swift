import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import YomidoriCore
import YomidoriDictionary

/// JPEGs in Application Support, one per id, scaled down so a page is a megabyte or two.
enum StillArchive {
    static let longestSide: CGFloat = 2000

    static func directory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil,
            create: true)
        let directory = base.appendingPathComponent("Stills", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func url(for id: UUID) throws -> URL {
        try directory().appendingPathComponent("\(id.uuidString).jpg")
    }

    @discardableResult
    static func save(_ still: Still) throws -> UUID {
        let id = UUID()
        let destination = try url(for: id)
        guard
            let sink = CGImageDestinationCreateWithURL(
                destination as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
        else { throw CocoaError(.fileWriteUnknown) }
        let scale = min(1, longestSide / max(still.size.width, still.size.height))
        let image = scale < 1 ? scaled(still.image, by: scale) ?? still.image : still.image
        CGImageDestinationAddImage(
            sink, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        guard CGImageDestinationFinalize(sink) else { throw CocoaError(.fileWriteUnknown) }
        return id
    }

    static func load(_ id: UUID) -> CGImage? {
        guard let url = try? url(for: id),
            let source = CGImageSourceCreateWithURL(url as CFURL, nil)
        else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    /// Deletes the files no card refers to any more; a still is shared by every card kept
    /// from its page.
    static func remove(_ ids: [UUID], keptBy cards: [Card]) {
        let referenced = Set(
            cards.flatMap(\.sightings).flatMap { $0.stillIDs + [$0.cropID].compactMap { $0 } })
        for id in ids where !referenced.contains(id) {
            if let url = try? url(for: id) {
                try? FileManager.default.removeItem(at: url)
            }
        }
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

enum Cards {
    static let store: FileCardStore? = try? FileCardStore.inApplicationSupport()

    /// The pitch is asked of the cards whose accent the dictionary knows.
    static func dueItems(at date: Date) -> [ReviewItem] {
        store?.dueItems(at: date, asksPitch: { !accents(of: $0).isEmpty }) ?? []
    }

    static func accents(of card: Card) -> [PitchAccent] {
        JMdict.bundled?.pitchAccents(for: card.headword, reading: card.reading) ?? []
    }
}
