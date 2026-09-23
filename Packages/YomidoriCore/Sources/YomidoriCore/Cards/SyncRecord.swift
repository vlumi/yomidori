import Foundation

/// What sync keeps in iCloud, one record per card, collection and looked-up word, and one
/// for the date the history was last cleared.
public enum SyncKind: String, CaseIterable, Sendable {
    case card
    case collection
    case lookup
    case historyCleared = "history"

    /// The record's type in CloudKit.
    public var recordType: String {
        switch self {
        case .card: return "Card"
        case .collection: return "Collection"
        case .lookup: return "Lookup"
        case .historyCleared: return "HistoryClear"
        }
    }
}

/// A record's name in iCloud: its kind and its store key. CloudKit wants names in ASCII, so
/// a lookup's key, a word and its reading, is percent-encoded.
public struct SyncName: Equatable, Hashable, Sendable {
    public let kind: SyncKind
    public let key: String

    public init(_ kind: SyncKind, _ key: String) {
        self.kind = kind
        self.key = key
    }

    public static let historyCleared = SyncName(.historyCleared, "cleared")

    public var recordName: String {
        "\(kind.rawValue)-"
            + (key.addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(["-"])) ?? key)
    }

    public init?(recordName: String) {
        guard let dash = recordName.firstIndex(of: "-"),
            let kind = SyncKind(rawValue: String(recordName[..<dash])),
            let key = String(recordName[recordName.index(after: dash)...]).removingPercentEncoding
        else { return nil }
        self.init(kind, key)
    }
}

/// A record's content as it travels: the same JSON the stores write.
public enum SyncPayload {
    public static func encode<Record: Encodable>(_ record: Record) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(record)
    }

    public static func decode<Record: Decodable>(_ type: Record.Type, from data: Data) throws
        -> Record
    {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }
}
