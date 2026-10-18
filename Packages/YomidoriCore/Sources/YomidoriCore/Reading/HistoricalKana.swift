import Foundation

/// Prewar spelling's kana as modern spelling has them, for a word the dictionary has no
/// entry for as written: 思ふ as 思う, 言ひ as 言い, あはれ as あわれ, ゐる as いる, 終つた as
/// 終った. One kana for one, so every offset stays where it was. Never across a whole line:
/// は, へ and を are still so written as particles.
public enum HistoricalKana {
    /// The text in modern kana; nil where nothing changes. `next` is what follows the text
    /// on the page, which decides a final つ (終つ before た).
    public static func modern(_ text: String, before next: String? = nil) -> String? {
        let scalars = Array(text.unicodeScalars)
        let following = next?.unicodeScalars.first
        var out = String.UnicodeScalarView()
        var changed = false
        for (index, scalar) in scalars.enumerated() {
            let after = index + 1 < scalars.count ? scalars[index + 1] : following
            let modern = replacement(for: scalar, first: index == 0, before: after) ?? scalar
            changed = changed || modern != scalar
            out.append(modern)
        }
        return changed ? String(out) : nil
    }

    private static func replacement(
        for scalar: Unicode.Scalar, first: Bool, before next: Unicode.Scalar?
    ) -> Unicode.Scalar? {
        // ゐ and ゑ are gone wherever they stand.
        if let gone = obsolete[scalar] { return gone }
        // A word begins with はひふへほ and を as written today (はな, ひと); inside one they
        // were read わいうえお.
        guard !first else { return nil }
        if let vowel = inside[scalar] { return vowel }
        // The small っ was printed full size: before a k, s, t or p sound it is the doubling
        // (終つた, 待つて).
        guard scalar == "つ", let next, doubled.contains(next.value) else { return nil }
        return "っ"
    }

    private static let obsolete: [Unicode.Scalar: Unicode.Scalar] = ["ゐ": "い", "ゑ": "え"]
    private static let inside: [Unicode.Scalar: Unicode.Scalar] = [
        "は": "わ", "ひ": "い", "ふ": "う", "へ": "え", "ほ": "お", "を": "お",
    ]

    /// か–ご, さ–ぞ, た–ど and the ぱ row.
    private static let doubled: Set<UInt32> = Set(
        Array(0x304B...0x3054) + Array(0x3055...0x305E) + Array(0x305F...0x3069)
            + [0x3071, 0x3074, 0x3077, 0x307A, 0x307D])
}
