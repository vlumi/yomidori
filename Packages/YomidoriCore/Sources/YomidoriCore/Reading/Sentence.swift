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

    /// Into `text` as `joined` made it: the paragraph indent before the sentence is not counted.
    public func offset(of index: String.Index, in text: String) -> Int {
        text[range.lowerBound..<index].filter { !$0.isNewline }.drop(while: \.isWhitespace).count
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
