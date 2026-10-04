import Foundation

/// A page read once, when its text is known: every line cut into chunks, the words and the
/// pieces between them, each with its place in the page's text. Everything after is a
/// lookup here: a tap in the strip or on the picture, a selection, the drawer's rows.
public struct PageReading: Sendable {
    public struct Chunk: Equatable, Sendable, Identifiable {
        /// The chunk's place among the page's chunks.
        public let id: Int
        public let line: Int
        /// Characters of the page's text.
        public let range: Range<Int>
        /// Its tokens, which index the line's own text, as a sentence to keep needs.
        public let word: FoundWord
        /// A word to look up; else punctuation, a particle or an ending, shown but not read.
        public let isWord: Bool
        /// The words a joined word is made of (木馬 in トロイの木馬), each to keep by itself;
        /// empty for a word of one piece.
        public let parts: [FoundWord]

        public var surface: String { word.surface }
    }

    public let text: String
    public let lines: TranscriptLines
    public let tokenLines: [[Token]]
    public let chunks: [Chunk]
    /// The chunks of each line, for a page drawn line by line.
    public let chunksByLine: [[Chunk]]
    /// Where the line breaks fall in `text`, in characters, for a range to be checked
    /// against without walking the text.
    public let lineBreaks: [Int]

    public init(
        text: String, tokens: (String) -> [Token], dictionary: (any WordDictionary)?
    ) {
        self.text = text
        lines = TranscriptLines(text)
        tokenLines = lines.lines.map(tokens)
        var chunks: [Chunk] = []
        // Each line's start counted on from the one before, not from the top of the page.
        var counted = (index: text.startIndex, offset: 0)
        for (line, lineTokens) in tokenLines.enumerated() {
            let lineText = lines.lines[line]
            let lineStart =
                counted.offset + text.distance(from: counted.index, to: lines.starts[line])
            counted = (lines.starts[line], lineStart)
            for segment in WordFinder.segments(in: lineTokens, dictionary: dictionary) {
                let first = segment.word.tokens[0].range.lowerBound
                let last = segment.word.tokens[segment.word.tokens.count - 1].range.upperBound
                let start = lineStart + lineText.distance(from: lineText.startIndex, to: first)
                let end = lineStart + lineText.distance(from: lineText.startIndex, to: last)
                chunks.append(
                    Chunk(
                        id: chunks.count, line: line, range: start..<end, word: segment.word,
                        isWord: segment.isShown,
                        parts: segment.isShown
                            ? WordFinder.parts(of: segment.word, dictionary: dictionary) : []))
            }
        }
        self.chunks = chunks
        var byLine = Array(repeating: [Chunk](), count: tokenLines.count)
        for chunk in chunks { byLine[chunk.line].append(chunk) }
        chunksByLine = byLine
        var breaks: [Int] = []
        for (offset, character) in text.enumerated() where character.isNewline {
            breaks.append(offset)
        }
        lineBreaks = breaks
    }

    /// Whether a range of the page's text, in characters, runs over a line break.
    public func spansLines(_ range: Range<Int>) -> Bool {
        lineBreaks.contains { range.contains($0) }
    }

    /// The chunk holding the character at `offset` of the page's text.
    public func chunk(at offset: Int) -> Chunk? {
        chunks.first { $0.range.contains(offset) }
    }

    /// The chunks a range of the page's text touches, in order.
    public func chunks(in range: Range<Int>) -> [Chunk] {
        chunks.filter { $0.range.overlaps(range) }
    }

    /// From one chunk to another, whichever comes first, as one range of the page's text.
    public static func range(from first: Chunk, to second: Chunk) -> Range<Int> {
        range(first.range, stretchedTo: second)
    }

    /// A selection stretched to a chunk, whichever way the chunk lies from it.
    public static func range(_ selected: Range<Int>, stretchedTo chunk: Chunk) -> Range<Int> {
        let lower = min(selected.lowerBound, chunk.range.lowerBound)
        let upper = max(selected.upperBound, chunk.range.upperBound)
        return lower..<upper
    }

    /// A range grown to the chunks it touches, so a selection never cuts a word.
    public func whole(_ range: Range<Int>) -> Range<Int>? {
        let touched = chunks(in: range)
        guard let first = touched.first, let last = touched.last else { return nil }
        return first.range.lowerBound..<last.range.upperBound
    }

    /// The sentence a range of the page's text starts in, from the full stop before it to the
    /// next, line breaks dropped; empty for a range outside the text.
    public func sentence(around range: Range<Int>) -> String {
        guard range.lowerBound >= 0, range.lowerBound < text.count else { return "" }
        let index = text.index(text.startIndex, offsetBy: range.lowerBound)
        return Sentence.around(index, in: text).text
    }

    /// The page's text over `range`, the line breaks dropped, as a phrase to look up.
    public func phrase(_ range: Range<Int>) -> String {
        let characters = Array(text)
        let range = range.clamped(to: 0..<characters.count)
        return String(characters[range].filter { !$0.isNewline })
    }
}
