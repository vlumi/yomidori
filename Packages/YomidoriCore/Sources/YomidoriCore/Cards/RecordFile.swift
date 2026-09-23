import Foundation

/// Who made a change: this device, or another one through sync. Sync sends only the local.
public enum ChangeOrigin: Sendable {
    case local
    case remote
}

/// The records a write saved or deleted, by key.
public struct RecordChange: Equatable, Sendable {
    public var saved: [String] = []
    public var deleted: [String] = []

    public var isEmpty: Bool { saved.isEmpty && deleted.isEmpty }

    public init(saved: [String] = [], deleted: [String] = []) {
        self.saved = saved
        self.deleted = deleted
    }

    /// What changed between two versions of a store's records.
    public static func between<Record: Equatable>(
        _ old: [Record], _ new: [Record], key: (Record) -> String
    ) -> RecordChange {
        let before = Dictionary(old.map { (key($0), $0) }, uniquingKeysWith: { first, _ in first })
        let after = Set(new.map(key))
        return RecordChange(
            saved: new.filter { before[key($0)] != $0 }.map(key),
            deleted: old.map(key).filter { !after.contains($0) })
    }
}

/// A store's records as one JSON document, written whole and atomically: loaded once,
/// changed under a lock, and every write reported by key with its origin, outside the lock
/// so a listener may read back. The cards, the collections and the history each have one.
public final class RecordFile<Record: Codable & Equatable>: @unchecked Sendable {
    public let url: URL
    private let key: (Record) -> String
    private let queue: DispatchQueue
    private var loaded: [Record]?
    public var onChange: ((RecordChange, ChangeOrigin) -> Void)?

    public init(url: URL, label: String, key: @escaping (Record) -> String) {
        self.url = url
        self.key = key
        queue = DispatchQueue(label: label)
    }

    public func records() -> [Record] {
        queue.sync { all() }
    }

    /// Changes the records in one write; nothing is written, or reported, when nothing changed.
    @discardableResult
    public func write<Result>(
        _ origin: ChangeOrigin = .local, _ transform: (inout [Record]) throws -> Result
    ) throws -> Result {
        let (result, change) = try queue.sync { () -> (Result, RecordChange) in
            let old = all()
            var records = old
            let result = try transform(&records)
            let change = RecordChange.between(old, records, key: key)
            if !change.isEmpty { try save(records) }
            return (result, change)
        }
        if !change.isEmpty { onChange?(change, origin) }
        return result
    }

    private func all() -> [Record] {
        if let loaded { return loaded }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let records =
            (try? Data(contentsOf: url)).flatMap { try? decoder.decode([Record].self, from: $0) }
            ?? []
        loaded = records
        return records
    }

    private func save(_ records: [Record]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(records).write(to: url, options: .atomic)
        loaded = records
    }
}

/// Another device's records laid over this one's: the saved replace or join by key, the
/// deleted go. The caller has already merged where both sides changed.
extension Array {
    public mutating func apply(
        saving saved: [Element], deleting deleted: Set<String>, key: (Element) -> String
    ) {
        removeAll { deleted.contains(key($0)) }
        for record in saved {
            if let index = firstIndex(where: { key($0) == key(record) }) {
                self[index] = record
            } else {
                append(record)
            }
        }
    }
}
