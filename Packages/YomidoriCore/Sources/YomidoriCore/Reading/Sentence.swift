import Foundation

/// A sentence as it stood on the page: the text around a word from the previous
/// full stop to the next, with the page's line breaks dropped, since in a book a
/// line break is a wrap and Japanese has no space to lose. A sentence with no
/// full stop before the page ends is open: it continues on the next page.
public struct Sentence: Equatable, Sendable {
    public let text: String
    /// Where the sentence sits in the text it was cut from, line breaks included.
    public let range: Range<String.Index>
    public let isOpen: Bool

    static let terminators: Set<Character> = ["。", "！", "？", "!", "?", "．", "…"]
    static let closers: Set<Character> = ["」", "』", "）", ")", "”", "’"]

    /// The sentence containing `index`.
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

    /// The start of a page that continues a sentence left open on the one before:
    /// everything up to and including the first full stop, or the whole page.
    public static func continuation(of text: String) -> Sentence {
        guard let first = text.firstIndex(where: { !$0.isNewline }) else {
            return Sentence(text: "", range: text.startIndex..<text.startIndex, isOpen: true)
        }
        return around(first, in: text)
    }

    /// The word's position in the sentence's text, in characters, line breaks dropped.
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
