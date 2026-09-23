import Foundation
import YomidoriCore
import YomidoriDictionary
import YomidoriSync

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
    static let didChange = Notification.Name("fi.misaki.yomidori.storesDidChange")
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
        CoverArchive.migrate(covers: stores.collections.collections().compactMap(\.coverID))
        stores.cards.file.onChange = { changed(.card, $0, $1) }
        stores.collections.file.onChange = { changed(.collection, $0, $1) }
        stores.lookups.file.onChange = { changed(.lookup, $0, $1) }
        stores.lookups.onClear = { _ in Sync.engine?.historyCleared() }
        if DemoMode.isRequested {
            DemoData.seed(
                cards: stores.cards, collections: stores.collections, lookups: stores.lookups)
        }
        return stores
    }()

    /// Every write refreshes the screens; this device's own also go to sync.
    private static func changed(_ kind: SyncKind, _ change: RecordChange, _ origin: ChangeOrigin) {
        if origin == .local { Sync.engine?.recordsChanged(kind, change) }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: didChange, object: nil)
        }
    }

    /// The stores as sync sees them, covers included.
    static var syncStores: CloudSync.Stores? {
        guard let stores else { return nil }
        return CloudSync.Stores(
            cards: stores.cards, collections: stores.collections, lookups: stores.lookups,
            coverURL: { id in
                (try? CoverArchive.url(for: id)).flatMap {
                    FileManager.default.fileExists(atPath: $0.path) ? $0 : nil
                }
            },
            saveCover: { id, url in
                // Decoded with care and drawn anew, never copied as it came.
                guard
                    let image = ImageIntake.image(
                        at: url, longestSide: Int(CoverArchive.longestSide))
                else { return }
                _ = try? CoverArchive.save(image, as: id)
            })
    }

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
        Set((store?.cards() ?? []).map(\.wordKey))
    }

    static func removeCollection(_ collection: Collection) {
        try? store?.forget(collection: collection.id)
        try? collections?.remove(collection)
        if let cover = collection.coverID {
            CoverArchive.remove([cover])
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
