import Foundation

/// A word looked up: opened from a search, or shown under a page. One line per word, the
/// latest date, so the reader can come back to a word they did not keep.
public struct Lookup: Identifiable, Hashable, Codable, Sendable {
    public enum Source: String, Codable, Sendable {
        case search
        case page
    }

    public let headword: String
    public let reading: String
    public let entryID: Int
    public let date: Date
    public let source: Source

    public var id: String { WordKey.of(headword: headword, reading: reading) }

    public init(headword: String, reading: String, entryID: Int, date: Date, source: Source) {
        self.headword = headword
        self.reading = reading
        self.entryID = entryID
        self.date = date
        self.source = source
    }

    /// Particles, auxiliaries and the copula are not lookups worth a line.
    public static func isWorthKeeping(_ entry: DictionaryEntry) -> Bool {
        !entry.isFunctionWord
    }
}

public protocol LookupHistory {
    func lookups() -> [Lookup]
    func record(_ lookup: Lookup) throws
    func remove(_ lookup: Lookup) throws
    func clear() throws
}

extension Lookup {
    /// The same word looked up on two devices: the later lookup stands.
    public func merged(with other: Lookup) -> Lookup {
        other.date > date ? other : self
    }
}

/// One JSON document, newest first, a word once, at most `limit` lines. A clear is a date
/// kept beside it, so a device that was offline drops what it had from before the clear
/// instead of bringing it back.
public final class FileLookupHistory: LookupHistory {
    public static let limit = 500
    public let file: RecordFile<Lookup>
    private let clearedURL: URL
    private let now: () -> Date
    /// Told of a clear made here, for sync to send.
    public var onClear: ((Date) -> Void)?

    public init(url: URL, now: @escaping () -> Date = Date.init) {
        file = RecordFile(url: url, label: "fi.misaki.yomidori.lookups") { $0.id }
        clearedURL = url.deletingPathExtension().appendingPathExtension("cleared.json")
        self.now = now
    }

    public var clearedAt: Date? {
        (try? Data(contentsOf: clearedURL)).flatMap {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try? decoder.decode(Date.self, from: $0)
        }
    }

    public func lookups() -> [Lookup] {
        file.records()
    }

    public func record(_ lookup: Lookup) throws {
        try file.write { all in
            all.removeAll { $0.id == lookup.id }
            all.insert(lookup, at: 0)
            all = Array(all.prefix(Self.limit))
        }
    }

    public func remove(_ lookup: Lookup) throws {
        try file.write { $0.removeAll { $0.id == lookup.id } }
    }

    public func clear() throws {
        let date = now()
        try setClearedAt(date)
        try file.write { $0 = [] }
        onClear?(date)
    }

    /// Another device's lookups and clear: nothing older than the latest clear survives.
    public func applyRemote(saving saved: [Lookup], deleting deleted: Set<String>, clearedAt: Date?)
        throws
    {
        if let clearedAt, clearedAt > (self.clearedAt ?? .distantPast) {
            try setClearedAt(clearedAt)
        }
        let cutoff = self.clearedAt ?? .distantPast
        try file.write(.remote) { all in
            all.apply(saving: saved.filter { $0.date > cutoff }, deleting: deleted, key: \.id)
            all.removeAll { $0.date <= cutoff }
            all.sort { $0.date > $1.date }
            all = Array(all.prefix(Self.limit))
        }
    }

    private func setClearedAt(_ date: Date) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(date).write(to: clearedURL, options: .atomic)
    }
}
