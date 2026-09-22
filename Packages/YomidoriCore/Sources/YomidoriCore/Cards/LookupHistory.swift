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

    public var id: String { "\(headword) \(reading)" }

    public init(headword: String, reading: String, entryID: Int, date: Date, source: Source) {
        self.headword = headword
        self.reading = reading
        self.entryID = entryID
        self.date = date
        self.source = source
    }

    /// Particles, auxiliaries and the copula are not lookups worth a line, by JMdict's own
    /// marks: skipped when every sense is one of those.
    public static func isWorthKeeping(_ entry: DictionaryEntry) -> Bool {
        let function: Set<String> = ["prt", "aux", "aux-v", "aux-adj", "cop"]
        let marked = entry.senses.filter { !$0.partsOfSpeech.isEmpty }
        return marked.isEmpty
            || marked.contains { sense in
                !sense.partsOfSpeech.allSatisfy(function.contains)
            }
    }
}

public protocol LookupHistory {
    func lookups() -> [Lookup]
    func record(_ lookup: Lookup) throws
    func remove(_ lookup: Lookup) throws
    func clear() throws
}

/// One JSON document, newest first, a word once, at most `limit` lines.
public final class FileLookupHistory: LookupHistory {
    public static let limit = 500
    private let url: URL
    private var loaded: [Lookup]?

    public init(url: URL) {
        self.url = url
    }

    public func lookups() -> [Lookup] {
        if let loaded { return loaded }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let lookups =
            (try? Data(contentsOf: url)).flatMap { try? decoder.decode([Lookup].self, from: $0) }
            ?? []
        loaded = lookups
        return lookups
    }

    public func record(_ lookup: Lookup) throws {
        var all = lookups().filter { $0.id != lookup.id }
        all.insert(lookup, at: 0)
        try write(Array(all.prefix(Self.limit)))
    }

    public func remove(_ lookup: Lookup) throws {
        try write(lookups().filter { $0.id != lookup.id })
    }

    public func clear() throws {
        try write([])
    }

    private func write(_ lookups: [Lookup]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(lookups).write(to: url, options: .atomic)
        loaded = lookups
    }
}
