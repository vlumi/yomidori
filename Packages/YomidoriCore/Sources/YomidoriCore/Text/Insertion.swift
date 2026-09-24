import Foundation

/// A piece of text put into a field where its cursor is, or over what is selected there.
public enum Insertion {
    public struct Result: Equatable, Sendable {
        public let text: String
        /// Right after the piece, in UTF-16 units, as a field's cursor counts.
        public let cursor: Int
    }

    /// `selection` in UTF-16 units; nil puts the piece at the end, and one out of date is held
    /// to the text. A bound inside a character (half an emoji, a letter and its combining
    /// mark) moves out to the character's edge, so nothing is split.
    public static func insert(_ piece: String, into text: String, replacing selection: Range<Int>?)
        -> Result
    {
        let characters = text as NSString
        let count = characters.length
        let lower = edge(
            min(max(selection?.lowerBound ?? count, 0), count), in: characters, up: false)
        // A cursor stays a point; only a selection widens out to whole characters.
        let isCursor = selection?.isEmpty ?? true
        let end = min(max(selection?.upperBound ?? count, lower), count)
        let upper = isCursor ? lower : edge(end, in: characters, up: true)
        let result = characters.replacingCharacters(
            in: NSRange(location: lower, length: max(upper - lower, 0)), with: piece)
        return Result(text: result, cursor: lower + (piece as NSString).length)
    }

    private static func edge(_ offset: Int, in text: NSString, up: Bool) -> Int {
        guard offset > 0, offset < text.length else { return offset }
        let character = text.rangeOfComposedCharacterSequence(at: offset)
        guard character.location != offset else { return offset }
        return up ? character.location + character.length : character.location
    }
}

/// Character offsets made into a range of a particular text, only when they fit it: a range
/// kept from another text (the page before a retake) must never reach the APIs that trap on it.
public enum CharacterRange {
    public static func of(_ range: Range<Int>, in text: String) -> Range<String.Index>? {
        guard range.lowerBound >= 0, range.upperBound <= text.count else { return nil }
        let lower = text.index(text.startIndex, offsetBy: range.lowerBound)
        return lower..<text.index(lower, offsetBy: range.count)
    }
}
