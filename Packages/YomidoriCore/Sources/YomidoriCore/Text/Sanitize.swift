import Foundation

/// Text from outside the app (a shared file, another device, the clipboard) made safe to
/// show and store: control characters, bidirectional overrides and isolates, which can make
/// text read other than it is, and byte-order marks go, and it is cut to a length.
public enum Sanitize {
    public static func text(_ text: String, limit: Int, keepsNewlines: Bool = false) -> String {
        var kept = String.UnicodeScalarView()
        for scalar in text.unicodeScalars where isAllowed(scalar, keepsNewlines: keepsNewlines) {
            kept.append(scalar)
        }
        return String(String(kept).prefix(limit))
    }

    /// Each item cleaned and cut, empty ones dropped, at most `count` of them.
    public static func texts(_ texts: [String], count: Int, limit: Int) -> [String] {
        texts.lazy.map { text($0, limit: limit) }.filter { !$0.isEmpty }.prefix(count).map { $0 }
    }

    private static func isAllowed(_ scalar: Unicode.Scalar, keepsNewlines: Bool) -> Bool {
        switch scalar.value {
        case 0x0A: return keepsNewlines
        case 0x09: return true
        case 0x00...0x1F, 0x7F...0x9F: return false
        // Bidirectional embeddings, overrides and isolates; the marks LRM, RLM and ALM.
        case 0x202A...0x202E, 0x2066...0x2069, 0x200E, 0x200F, 0x061C: return false
        // Line and paragraph separators, and the byte-order mark.
        case 0x2028, 0x2029, 0xFEFF: return false
        default: return true
        }
    }
}
