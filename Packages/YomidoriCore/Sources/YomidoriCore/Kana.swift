/// Hiragana and katakana are parallel Unicode blocks, so a conversion is one scalar offset.
public enum Kana {
    private static let hiraganaRange: ClosedRange<UInt32> = 0x3041...0x3096
    private static let katakanaRange: ClosedRange<UInt32> = 0x30A1...0x30F6
    private static let offset: UInt32 = 0x30A1 - 0x3041

    /// Kanji, Latin, ー and the katakana-only ヷ–ヺ pass through unchanged.
    public static func hiragana(_ text: String) -> String {
        map(text, from: katakanaRange, by: -Int32(offset))
    }

    public static func katakana(_ text: String) -> String {
        map(text, from: hiraganaRange, by: Int32(offset))
    }

    public static func isKana(_ text: String) -> Bool {
        !text.isEmpty
            && text.unicodeScalars.allSatisfy {
                hiraganaRange.contains($0.value) || katakanaRange.contains($0.value)
                    || $0.value == 0x30FC
            }
    }

    private static func map(_ text: String, from range: ClosedRange<UInt32>, by delta: Int32)
        -> String
    {
        var scalars = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            if range.contains(scalar.value),
                let moved = Unicode.Scalar(UInt32(Int32(scalar.value) + delta))
            {
                scalars.append(moved)
            } else {
                scalars.append(scalar)
            }
        }
        return String(scalars)
    }
}
