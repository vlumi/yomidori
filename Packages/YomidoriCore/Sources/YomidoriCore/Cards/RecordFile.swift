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
    /// Records this build could not read (written by a newer one, say), kept as they were and
    /// written back untouched, so a file is never shrunk by what cannot be decoded.
    private var unreadable: [Any] = []
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

    /// Record by record: one that does not decode is set aside, not the whole file lost with
    /// it. A file that is no JSON array at all is moved aside, never written over.
    private func all() -> [Record] {
        if let loaded { return loaded }
        var records: [Record] = []
        unreadable = []
        if let data = try? Data(contentsOf: url) {
            if let elements = (try? JSONSerialization.jsonObject(with: data)) as? [Any] {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                for element in elements {
                    if let json = try? JSONSerialization.data(withJSONObject: element),
                        let record = try? decoder.decode(Record.self, from: json)
                    {
                        records.append(record)
                    } else {
                        unreadable.append(element)
                    }
                }
            } else {
                setAside()
            }
        }
        loaded = records
        return records
    }

    private func save(_ records: [Record]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        var data = try encoder.encode(records)
        if !unreadable.isEmpty,
            let readable = try JSONSerialization.jsonObject(with: data) as? [Any]
        {
            data = try JSONSerialization.data(
                withJSONObject: readable + unreadable, options: [.prettyPrinted, .sortedKeys])
        }
        try data.write(to: url, options: .atomic)
        loaded = records
    }

    /// The unreadable file kept beside the store under a dated name, for recovery by hand.
    private func setAside() {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(
            of: ":", with: "-")
        let aside = url.deletingPathExtension().appendingPathExtension("unreadable-\(stamp).json")
        try? FileManager.default.moveItem(at: url, to: aside)
    }
}

/// Another device's records laid over this one's: the saved replace or join by key, the
/// deleted go. The caller has already merged where both sides changed.
extension Array {
    public mutating func apply(
        saving saved: [Element], deleting deleted: Set<String>, key: (Element) -> String
    ) {
        removeAll { deleted.contains(key($0)) }
        var places = Dictionary(
            enumerated().map { (key($0.element), $0.offset) },
            uniquingKeysWith: { first, _ in first })
        for record in saved {
            let recordKey = key(record)
            if let index = places[recordKey] {
                self[index] = record
            } else {
                places[recordKey] = count
                append(record)
            }
        }
    }
}
