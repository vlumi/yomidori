import Foundation

/// Whether a typed reading is the card's. Strict on the kana, forgiving on what is
/// not reading: katakana counts as its hiragana, spaces and a trailing return are
/// ignored, and the half-width kana some keyboards produce are read as full-width.
public enum ReadingCheck {
    public static func matches(typed: String, reading: String) -> Bool {
        !typed.isEmpty && normalize(typed) == normalize(reading)
    }

    static func normalize(_ text: String) -> String {
        let folded = text.applyingTransform(.fullwidthToHalfwidth, reverse: true) ?? text
        return Kana.hiragana(folded).filter { !$0.isWhitespace && !$0.isNewline }
    }
}
