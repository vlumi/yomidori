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
    /// Stamped by the store on every save; between devices the later version wins whole.
    public var modified: Date

    public init(
        id: UUID = UUID(), name: String, created: Date = Date(), note: String = "",
        tags: [String] = [], coverID: UUID? = nil, modified: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.created = created
        self.note = note
        self.tags = tags
        self.coverID = coverID
        self.modified = modified ?? created
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, created, note, tags, coverID, modified
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        created = try c.decode(Date.self, forKey: .created)
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        coverID = try c.decodeIfPresent(UUID.self, forKey: .coverID)
        modified = try c.decodeIfPresent(Date.self, forKey: .modified) ?? created
    }

    public func merged(with other: Collection) -> Collection {
        other.modified > modified ? other : self
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
    public let file: RecordFile<Collection>
    private let now: () -> Date

    public init(url: URL, now: @escaping () -> Date = Date.init) {
        file = RecordFile(url: url, label: "fi.misaki.yomidori.collections") { $0.id.uuidString }
        self.now = now
    }

    public func collections() -> [Collection] {
        file.records()
    }

    /// Adds the collection, or replaces the one with its id.
    public func save(_ collection: Collection) throws {
        var stamped = collection
        stamped.modified = now()
        try file.write { all in
            if let index = all.firstIndex(where: { $0.id == collection.id }) {
                guard !all[index].sameContent(as: collection) else { return }
                all[index] = stamped
            } else {
                all.append(stamped)
            }
        }
    }

    public func remove(_ collection: Collection) throws {
        try file.write { $0.removeAll { $0.id == collection.id } }
    }

    public func applyRemote(saving saved: [Collection], deleting deleted: Set<UUID>) throws {
        try file.write(.remote) {
            $0.apply(saving: saved, deleting: Set(deleted.map(\.uuidString)), key: \.id.uuidString)
        }
    }
}

extension Collection {
    /// Equal but for when it was saved, so saving it unchanged is no change.
    func sameContent(as other: Collection) -> Bool {
        var stamped = other
        stamped.modified = modified
        return stamped == self
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
