import Foundation

/// A named group of cards, a book usually; a card can be in several. The tags are the
/// reader's own words (book, magazine, an author); the cover is a still kept by id.
public struct Collection: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public let created: Date
    public var note: String
    public var tags: [String]
    public var coverID: UUID?

    public init(
        id: UUID = UUID(), name: String, created: Date = Date(), note: String = "",
        tags: [String] = [], coverID: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.created = created
        self.note = note
        self.tags = tags
        self.coverID = coverID
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, created, note, tags, coverID
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        created = try c.decode(Date.self, forKey: .created)
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        coverID = try c.decodeIfPresent(UUID.self, forKey: .coverID)
    }

    /// Tags as typed, comma-separated, each once, empties dropped.
    public static func tags(from text: String) -> [String] {
        var seen: Set<String> = []
        return text.split(whereSeparator: { $0 == "," || $0 == "、" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }
}

extension Sequence where Element == Collection {
    /// Every tag in use, each once, in order of first use.
    public var allTags: [String] {
        var seen: Set<String> = []
        return flatMap(\.tags).filter { seen.insert($0.lowercased()).inserted }
    }
}

public protocol CollectionStore {
    func collections() -> [Collection]
    func save(_ collection: Collection) throws
    func remove(_ collection: Collection) throws
}

/// One JSON document beside the cards, written whole on every change.
public final class FileCollectionStore: CollectionStore {
    private let url: URL
    private var loaded: [Collection]?

    public init(url: URL) {
        self.url = url
    }

    public func collections() -> [Collection] {
        if let loaded { return loaded }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let collections =
            (try? Data(contentsOf: url)).flatMap {
                try? decoder.decode([Collection].self, from: $0)
            }
            ?? []
        loaded = collections
        return collections
    }

    /// Adds the collection, or replaces the one with its id.
    public func save(_ collection: Collection) throws {
        var all = collections()
        if let index = all.firstIndex(where: { $0.id == collection.id }) {
            all[index] = collection
        } else {
            all.append(collection)
        }
        try write(all)
    }

    public func remove(_ collection: Collection) throws {
        try write(collections().filter { $0.id != collection.id })
    }

    private func write(_ collections: [Collection]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(collections).write(to: url, options: .atomic)
        loaded = collections
    }
}

extension Sequence where Element == String {
    /// Tags match by the reader's own spelling, case aside.
    public func containsTag(_ tag: String) -> Bool {
        contains { $0.lowercased() == tag.lowercased() }
    }
}

extension Collection {
    public func hasTag(_ tag: String) -> Bool { tags.containsTag(tag) }
}
