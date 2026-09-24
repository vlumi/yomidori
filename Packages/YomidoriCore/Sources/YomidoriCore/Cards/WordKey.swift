import CryptoKit
import Foundation

/// The one key a word has across the cards, the history and a search: headword and reading.
///
/// Never change what it gives: a card's id is made from it, and every card kept would stop
/// matching its own record in iCloud.
public enum WordKey {
    public static func of(headword: String, reading: String) -> String {
        "\(headword) \(reading)"
    }

    /// The word's card id, the same on every device: a name-based UUID (version 5, RFC 9562)
    /// of the key in Yomidori's own namespace.
    public static func cardID(headword: String, reading: String) -> UUID {
        var bytes = Array(namespace)
        bytes += Array(of(headword: headword, reading: reading).utf8)
        var hash = Array(Insecure.SHA1.hash(data: bytes).prefix(16))
        hash[6] = (hash[6] & 0x0F) | 0x50
        hash[8] = (hash[8] & 0x3F) | 0x80
        return UUID(
            uuid: (
                hash[0], hash[1], hash[2], hash[3], hash[4], hash[5], hash[6], hash[7], hash[8],
                hash[9], hash[10], hash[11], hash[12], hash[13], hash[14], hash[15]
            ))
    }

    /// Fixed for good, like the key itself.
    private static let namespace: [UInt8] = {
        let uuid = UUID(uuidString: "6F0A6C2E-5B8D-4E1A-9C3F-2D7B8E4A1C59")!.uuid
        return withUnsafeBytes(of: uuid) { Array($0) }
    }()
}
