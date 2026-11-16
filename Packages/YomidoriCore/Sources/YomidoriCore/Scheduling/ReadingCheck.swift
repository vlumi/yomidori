import Foundation

/// Katakana counts as its hiragana and half-width kana as full-width; spaces and a
/// trailing return are ignored.
public enum ReadingCheck {
    public static func matches(typed: String, reading: String) -> Bool {
        !typed.isEmpty && normalize(typed) == normalize(reading)
    }

    /// Any of several readings, as a card whose word is also read another way accepts.
    public static func matches(typed: String, readings: [String]) -> Bool {
        readings.contains { matches(typed: typed, reading: $0) }
    }

    static func normalize(_ text: String) -> String {
        let folded = text.applyingTransform(.fullwidthToHalfwidth, reverse: true) ?? text
        return Kana.hiragana(folded).filter { !$0.isWhitespace && !$0.isNewline }
    }
}
