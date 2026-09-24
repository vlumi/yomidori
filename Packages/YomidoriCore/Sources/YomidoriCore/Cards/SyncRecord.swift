import CryptoKit
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

/// A record's name in iCloud: its kind and its store key. CloudKit wants names in ASCII and
/// no longer than 255 characters, so a lookup's key, a word and its reading, is
/// percent-encoded, and one too long for that (お誕生日おめでとうございます) is named by its
/// hash instead, which can't be read back into the key.
public struct SyncName: Equatable, Hashable, Sendable {
    public let kind: SyncKind
    public let key: String

    public init(_ kind: SyncKind, _ key: String) {
        self.kind = kind
        self.key = key
    }

    public static let historyCleared = SyncName(.historyCleared, "cleared")
    static let longest = 255
    /// Starts a hashed key; percent-encoding never writes it.
    private static let hashMark = "_"

    public var recordName: String {
        let spelled =
            "\(kind.rawValue)-"
            + (key.addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(["-"])) ?? key)
        guard spelled.utf8.count > Self.longest else { return spelled }
        let hash = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return "\(kind.rawValue)-\(Self.hashMark)\(hash)"
    }

    /// The name read back; nil for a hashed one, whose key only a list of keys can find (see
    /// `key(ofRecordName:among:)`).
    public init?(recordName: String) {
        guard let kind = Self.kind(ofRecordName: recordName) else { return nil }
        let rest = String(recordName.drop { $0 != "-" }.dropFirst())
        guard !rest.hasPrefix(Self.hashMark), let key = rest.removingPercentEncoding
        else { return nil }
        self.init(kind, key)
    }

    /// The kind of any record name this app writes, hashed or not.
    public static func kind(ofRecordName recordName: String) -> SyncKind? {
        guard let dash = recordName.firstIndex(of: "-") else { return nil }
        return SyncKind(rawValue: String(recordName[..<dash]))
    }

    /// The key a record name stands for, looked for among `keys` when the name is hashed.
    public static func key(
        ofRecordName recordName: String, among keys: @autoclosure () -> [String]
    ) -> String? {
        if let name = SyncName(recordName: recordName) { return name.key }
        guard let kind = kind(ofRecordName: recordName) else { return nil }
        return keys().first { SyncName(kind, $0).recordName == recordName }
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
