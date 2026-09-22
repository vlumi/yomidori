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
        let directory = try Cards.directory().appendingPathComponent("Stills", isDirectory: true)
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

/// The app's stores, in Application Support, or in the demo's folder when launched so; the
/// demo folder is seeded the first time it is asked for.
enum Cards {
    static func directory() throws -> URL {
        if DemoMode.isRequested { return DemoMode.directory }
        return try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil,
            create: true)
    }

    static let store: FileCardStore? = stores?.cards
    /// Posted after every write to the cards, for the counts shown outside the store's screens.
    static let cardsDidChange = Notification.Name("fi.misaki.yomidori.cardsDidChange")
    /// The settings the screens write to: the demo's own suite in the demo.
    static var defaults: UserDefaults { DemoMode.defaults ?? .standard }
    static let collections: FileCollectionStore? = stores?.collections
    static let lookups: FileLookupHistory? = stores?.lookups

    private struct Stores {
        let cards: FileCardStore
        let collections: FileCollectionStore
        let lookups: FileLookupHistory
    }

    private static let stores: Stores? = {
        guard let directory = try? directory() else { return nil }
        let stores = Stores(
            cards: FileCardStore(url: directory.appendingPathComponent("cards.json")),
            collections: FileCollectionStore(
                url: directory.appendingPathComponent("collections.json")),
            lookups: FileLookupHistory(url: directory.appendingPathComponent("lookups.json")))
        stores.cards.didChange = {
            NotificationCenter.default.post(name: cardsDidChange, object: nil)
        }
        if DemoMode.isRequested {
            DemoData.seed(
                cards: stores.cards, collections: stores.collections, lookups: stores.lookups)
        }
        return stores
    }()

    static func noteLookup(of entry: DictionaryEntry, from source: Lookup.Source) {
        guard Lookup.isWorthKeeping(entry) else { return }
        try? lookups?.record(
            Lookup(
                headword: entry.headword, reading: Kana.hiragana(entry.readings.first ?? ""),
                entryID: entry.id, date: Date(), source: source))
    }

    /// The collection Keep files a word under, remembered across screens; nil for none.
    static let currentCollectionKey = "currentCollection"

    static func currentCollectionID() -> UUID? {
        defaults.string(forKey: currentCollectionKey).flatMap(UUID.init)
    }

    /// The words that have a card, as "headword reading", for a mark in a list.
    static func keptWords() -> Set<String> {
        Set((store?.cards() ?? []).map { "\($0.headword) \($0.reading)" })
    }

    static func removeCollection(_ collection: Collection) {
        try? store?.forget(collection: collection.id)
        try? collections?.remove(collection)
        if let cover = collection.coverID {
            StillArchive.remove([cover], keptBy: store?.cards() ?? [])
        }
        if currentCollectionID() == collection.id {
            defaults.removeObject(forKey: currentCollectionKey)
        }
    }

    /// The pitch is asked of the cards whose accent the dictionary knows.
    static func dueItems(at date: Date) -> [ReviewItem] {
        store?.dueItems(at: date, asksPitch: { !accents(of: $0).isEmpty }) ?? []
    }

    static func accents(of card: Card) -> [PitchAccent] {
        JMdict.bundled?.pitchAccents(for: card.headword, reading: card.reading) ?? []
    }
}
