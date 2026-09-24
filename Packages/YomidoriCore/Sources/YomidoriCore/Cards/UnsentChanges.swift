import Foundation

/// What this device changed while sync was off, by record name, to be sent when it is on
/// again: the sync engine keeps its own list only while it runs.
public struct UnsentChanges: Codable, Equatable, Sendable {
    public private(set) var saved: Set<String> = []
    public private(set) var deleted: Set<String> = []

    public init() {}

    public var isEmpty: Bool { saved.isEmpty && deleted.isEmpty }

    /// The latest word on a record wins: a save after a delete sends the save.
    public mutating func note(_ kind: SyncKind, _ change: RecordChange) {
        for key in change.saved {
            let name = SyncName(kind, key).recordName
            saved.insert(name)
            deleted.remove(name)
        }
        for key in change.deleted {
            let name = SyncName(kind, key).recordName
            deleted.insert(name)
            saved.remove(name)
        }
    }

    public mutating func noteHistoryCleared() {
        saved.insert(SyncName.historyCleared.recordName)
    }

    public static func read(from url: URL) -> UnsentChanges {
        (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(Self.self, from: $0) }
            ?? UnsentChanges()
    }

    public func write(to url: URL) throws {
        if isEmpty {
            try? FileManager.default.removeItem(at: url)
        } else {
            try JSONEncoder().encode(self).write(to: url, options: .atomic)
        }
    }
}
