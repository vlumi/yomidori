import Foundation

/// The text around a word from the previous full stop to the next, line breaks dropped;
/// open when the page ends before a full stop. A quotation is one piece: a full stop inside
/// 「」 ends nothing, and what follows the quote — と呟いた — stays with it, unless the quote
/// stands on a line of its own, as dialogue does. A line that is only a number, a page's,
/// never joins.
public struct Sentence: Equatable, Sendable {
    public let text: String
    public let range: Range<String.Index>
    public let isOpen: Bool

    static let terminators: Set<Character> = ["。", "！", "？", "!", "?", "．", "…"]
    static let openers: Set<Character> = ["「", "『", "（", "(", "“", "‘"]
    static let closers: Set<Character> = ["」", "』", "）", ")", "”", "’"]

    /// A quotation kept whole up to this many characters; a longer one — a speech, a
    /// quotation running off the page — is cut at its own full stops like any text.
    static let longestQuotation = 120

    public static func around(_ index: String.Index, in text: String) -> Sentence {
        let whole = around(index, depth: quoteDepth(at: index, in: text), in: text)
        guard whole.text.count > longestQuotation else { return whole }
        return around(index, depth: 0, in: text)
    }

    private static func around(_ index: String.Index, depth: Int, in text: String) -> Sentence {
        let start = start(before: index, depth: depth, in: text)
        let (end, open) = end(from: index, depth: depth, in: text)
        return Sentence(text: joined(text[start..<end]), range: start..<end, isOpen: open)
    }

    /// How many quotations the word stands inside, counted from the top of the page; a
    /// closer with no opener before it (lost to the recognizer, say) counts for nothing.
    private static func quoteDepth(at index: String.Index, in text: String) -> Int {
        var depth = 0
        for character in text[..<index] {
            if openers.contains(character) {
                depth += 1
            } else if closers.contains(character) {
                depth = max(0, depth - 1)
            }
        }
        return depth
    }

    /// Back to the end of the sentence before: a full stop outside any quote, the line
    /// break before a quotation standing on its own, or a line of page furniture.
    private static func start(before index: String.Index, depth: Int, in text: String)
        -> String.Index
    {
        var start = index
        var depth = depth
        while start > text.startIndex {
            let before = text.index(before: start)
            let character = text[before]
            if character.isNewline, isFurniture(lineEnding: before, in: text) { break }
            if closers.contains(character) {
                if depth == 0, breaks(afterCloser: before, in: text) { break }
                depth += 1
            } else if openers.contains(character) {
                depth = max(0, depth - 1)
                // The word's own quotation, standing on a line of its own: it starts here.
                if depth == 0, standsAlone(openerAt: before, in: text) { return before }
            } else if terminators.contains(character), depth == 0 {
                break
            }
            start = before
        }
        return start
    }

    /// Forward to the sentence's end: a full stop outside any quote, with any closers after
    /// it; a quotation's closer when the quote stands on its own; or, open, a line of page
    /// furniture or the end of the text.
    private static func end(from index: String.Index, depth: Int, in text: String)
        -> (String.Index, Bool)
    {
        var end = index
        var depth = depth
        while end < text.endIndex {
            let character = text[end]
            if character.isNewline, isFurniture(lineStarting: text.index(after: end), in: text) {
                return (end, true)
            }
            end = text.index(after: end)
            if openers.contains(character) {
                depth += 1
            } else if closers.contains(character) {
                depth = max(0, depth - 1)
                if depth == 0, breaks(afterCloser: text.index(before: end), in: text) {
                    return (end, false)
                }
            } else if terminators.contains(character), depth == 0 {
                while end < text.endIndex, closers.contains(text[end]) {
                    end = text.index(after: end)
                }
                return (end, false)
            }
        }
        return (end, true)
    }

    /// A quotation's closer ends the sentence when the quotation stands on a line of its
    /// own, or when a full stop stands inside it and a line break right after: dialogue
    /// whose next paragraph has lost its indent to the recognizer.
    private static func breaks(afterCloser closer: String.Index, in text: String) -> Bool {
        let after = text.index(after: closer)
        if standsAlone(closerBefore: after, in: text) { return true }
        return endsSentence(before: closer, in: text) && after < text.endIndex
            && text[after].isNewline
    }

    /// A quotation on a line of its own ends where it closes: dialogue, one line a speaker.
    /// The closer is followed by the end, by another quotation, or by a new paragraph — a
    /// line break and then a quotation or an indent.
    private static func standsAlone(closerBefore end: String.Index, in text: String) -> Bool {
        var cursor = end
        var brokeLine = false
        while cursor < text.endIndex {
            let character = text[cursor]
            if character.isNewline {
                brokeLine = true
            } else if character == "　" {
                if brokeLine { return true }
            } else if !character.isWhitespace {
                return openers.contains(character)
            }
            cursor = text.index(after: cursor)
        }
        return true
    }

    /// The opener of the word's own quotation starts the sentence when the quotation stands
    /// on a line of its own: what is before it, across the line break, is a closer.
    private static func standsAlone(openerAt opener: String.Index, in text: String) -> Bool {
        var cursor = opener
        var brokeLine = false
        while cursor > text.startIndex {
            cursor = text.index(before: cursor)
            let character = text[cursor]
            if character.isNewline {
                brokeLine = true
            } else if !character.isWhitespace {
                return brokeLine && closers.contains(character)
            }
        }
        return true
    }

    /// A line that is only digits, Latin letters, spaces and marks: a page number, a running
    /// head, nothing a sentence wants.
    private static func isFurniture(lineStarting index: String.Index, in text: String) -> Bool {
        let line = text[index...].prefix { !$0.isNewline }
        return isFurniture(line)
    }

    private static func isFurniture(lineEnding index: String.Index, in text: String) -> Bool {
        var start = index
        while start > text.startIndex, !text[text.index(before: start)].isNewline {
            start = text.index(before: start)
        }
        return isFurniture(text[start..<index])
    }

    private static func isFurniture(_ line: Substring) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        return trimmed.allSatisfy { character in
            character.isNumber || character.isPunctuation || character.isWhitespace
                || character.isASCII
        }
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
