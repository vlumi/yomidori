import Foundation

/// Katakana counts as its hiragana and half-width kana as full-width; spaces and a
/// trailing return are ignored.
public enum ReadingCheck {
    public static func matches(typed: String, reading: String) -> Bool {
        !typed.isEmpty && normalize(typed) == normalize(reading)
    }

    static func normalize(_ text: String) -> String {
        let folded = text.applyingTransform(.fullwidthToHalfwidth, reverse: true) ?? text
        return Kana.hiragana(folded).filter { !$0.isWhitespace && !$0.isNewline }
    }
}
