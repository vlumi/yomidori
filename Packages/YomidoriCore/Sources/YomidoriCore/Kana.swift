/// Kana conversions. Tokenizer dictionaries give readings in katakana; a reading
/// shown to a reader wants hiragana. The two scripts are parallel blocks in
/// Unicode, so the conversion is an offset per scalar, over the range both share.
public enum Kana {
    private static let hiraganaRange: ClosedRange<UInt32> = 0x3041...0x3096
    private static let katakanaRange: ClosedRange<UInt32> = 0x30A1...0x30F6
    private static let offset: UInt32 = 0x30A1 - 0x3041

    /// The text with every katakana in the shared range read as hiragana; anything
    /// else (kanji, Latin, punctuation, the katakana-only ヷ–ヺ and the length mark ー)
    /// passes through unchanged.
    public static func hiragana(_ text: String) -> String {
        map(text, from: katakanaRange, by: -Int32(offset))
    }

    /// The reverse of `hiragana(_:)`.
    public static func katakana(_ text: String) -> String {
        map(text, from: hiraganaRange, by: Int32(offset))
    }

    /// True when the text is kana only (either script, with the length mark), so a
    /// word that is already all kana needs no reading shown over it.
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
