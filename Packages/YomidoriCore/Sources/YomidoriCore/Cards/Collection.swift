import Foundation

/// A named group of cards, a book usually; a card can be in several.
public struct Collection: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public let created: Date

    public init(id: UUID = UUID(), name: String, created: Date = Date()) {
        self.id = id
        self.name = name
        self.created = created
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

    /// Adds the collection, or renames the one with its id.
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
