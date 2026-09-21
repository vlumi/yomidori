import Foundation

/// The text around a word from the previous full stop to the next, line breaks dropped;
/// open when the page ends before a full stop.
public struct Sentence: Equatable, Sendable {
    public let text: String
    public let range: Range<String.Index>
    public let isOpen: Bool

    static let terminators: Set<Character> = ["。", "！", "？", "!", "?", "．", "…"]
    static let closers: Set<Character> = ["」", "』", "）", ")", "”", "’"]

    public static func around(_ index: String.Index, in text: String) -> Sentence {
        var start = index
        while start > text.startIndex {
            let before = text.index(before: start)
            if terminators.contains(text[before])
                || closers.contains(text[before]) && endsSentence(before: before, in: text)
            {
                break
            }
            start = before
        }
        var end = index
        var open = true
        while end < text.endIndex {
            let character = text[end]
            end = text.index(after: end)
            if terminators.contains(character) {
                while end < text.endIndex, closers.contains(text[end]) {
                    end = text.index(after: end)
                }
                open = false
                break
            }
        }
        return Sentence(text: joined(text[start..<end]), range: start..<end, isOpen: open)
    }

    /// The rest of a sentence left open on the page before: up to the first full stop, or the
    /// whole page.
    public static func continuation(of text: String) -> Sentence {
        guard let first = text.firstIndex(where: { !$0.isNewline }) else {
            return Sentence(text: "", range: text.startIndex..<text.startIndex, isOpen: true)
        }
        return around(first, in: text)
    }

    public func offset(of index: String.Index, in text: String) -> Int {
        text[range.lowerBound..<index].filter { !$0.isNewline }.count
    }

    private static func joined(_ slice: Substring) -> String {
        String(slice.filter { !$0.isNewline })
            .trimmingCharacters(in: .whitespaces)
    }

    /// A closer counts as an end only when a terminator stands right before it (「はい。」).
    private static func endsSentence(before index: String.Index, in text: String) -> Bool {
        var cursor = index
        while cursor > text.startIndex {
            cursor = text.index(before: cursor)
            if terminators.contains(text[cursor]) { return true }
            if !closers.contains(text[cursor]) { return false }
        }
        return false
    }
}
