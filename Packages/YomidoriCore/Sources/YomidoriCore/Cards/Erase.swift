import Foundation

/// When the reader last erased everything, as a date beside the stores. Sync carries it, so
/// a device that was away erases too, and stamps every record it sends with it, so a record
/// from a device that had not heard of the erase is known for what it is: the past.
public final class FileEraseMark: @unchecked Sendable {
    private let url: URL
    private let lock = NSLock()

    public init(url: URL) {
        self.url = url
    }

    /// To the second, as the file and the records keep it, so the same erase read back from
    /// anywhere compares equal.
    public var date: Date? {
        lock.withLock {
            (try? Data(contentsOf: url)).flatMap {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try? decoder.decode(Date.self, from: $0)
            }
        }
    }

    func set(_ date: Date) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try lock.withLock { try encoder.encode(Erase.second(date)).write(to: url, options: .store) }
    }
}

/// Everything the reader made, erased: from this device, and through sync from every other.
public enum Erase {
    public struct Stores {
        public let mark: FileEraseMark
        public let cards: FileCardStore
        public let collections: FileCollectionStore
        public let lookups: FileLookupHistory

        public init(
            mark: FileEraseMark, cards: FileCardStore, collections: FileCollectionStore,
            lookups: FileLookupHistory
        ) {
            self.mark = mark
            self.cards = cards
            self.collections = collections
            self.lookups = lookups
        }
    }

    /// The date to the second, as the records and the files carry it.
    public static func second(_ date: Date) -> Date {
        Date(timeIntervalSince1970: date.timeIntervalSince1970.rounded(.down))
    }

    /// The mark first, so an erase cut short still counts, then each store emptied in a
    /// write of its own, reported as this device's so sync sends the deletes; the history's
    /// clear goes with it, so a restore brings every lookup back. What only this device
    /// keeps, the covers and the ranks by day, is the caller's to clear.
    public static func everything(_ stores: Stores, at date: Date = Date()) throws {
        try stores.mark.set(date)
        try stores.cards.replaceAll { _ in [] }
        try stores.collections.replaceAll { _ in [] }
        try stores.lookups.replaceAll { _ in [] }
        stores.lookups.forgetClear()
    }

    /// Another device's erase: everything held goes, as a change from outside that is not
    /// sent back, and the mark is taken. One no newer than the mark known does nothing.
    /// Whether it was applied.
    @discardableResult
    public static func applyRemote(_ stores: Stores, at date: Date) throws -> Bool {
        let date = second(date)
        guard date > (stores.mark.date ?? .distantPast) else { return false }
        try stores.mark.set(date)
        try stores.cards.applyRemote(saving: [], deleting: Set(stores.cards.cards().map(\.id)))
        try stores.collections.applyRemote(
            saving: [], deleting: Set(stores.collections.collections().map(\.id)))
        try stores.lookups.applyRemote(
            saving: [], deleting: Set(stores.lookups.lookups().map(\.id)), clearedAt: nil)
        stores.lookups.forgetClear()
        return true
    }

    /// A record stamped `era` by a device that had not heard of the erase marked `mark`: the
    /// past, not to be taken. A record with no era was sent before any erase, or by a build
    /// that kept none.
    public static func isStale(era: Date?, mark: Date?) -> Bool {
        (era ?? .distantPast) < (mark ?? .distantPast)
    }

    /// A record from past an erase this device has not heard of yet.
    public static func isAhead(era: Date?, mark: Date?) -> Bool {
        (era ?? .distantPast) > (mark ?? .distantPast)
    }
}
