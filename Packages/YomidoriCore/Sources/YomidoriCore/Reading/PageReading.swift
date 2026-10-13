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
            // Along the line too, from the segment before, not from its start each time: a
            // page without line breaks is one long line, and counting from its start per
            // segment grew with the square of its length.
            var along = (index: lineText.startIndex, offset: lineStart)
            for segment in WordFinder.segments(in: lineTokens, dictionary: dictionary) {
                let first = segment.word.tokens[0].range.lowerBound
                let last = segment.word.tokens[segment.word.tokens.count - 1].range.upperBound
                let start = along.offset + lineText.distance(from: along.index, to: first)
                let end = start + lineText.distance(from: first, to: last)
                along = (last, end)
                chunks.append(
                    Chunk(
                        id: chunks.count, line: line, range: start..<end, word: segment.word,
                        isWord: segment.isShown,
                        parts: segment.isShown
                            ? WordFinder.parts(of: segment.word, dictionary: dictionary) : []))
            }
        }
        var byLine = Array(repeating: [Chunk](), count: tokenLines.count)
        for chunk in chunks { byLine[chunk.line].append(chunk) }
        byLine = Self.joinedAcrossLines(byLine, dictionary: dictionary)
        // Numbered once more, in order, after the joins.
        var numbered = 0
        for line in byLine.indices {
            for index in byLine[line].indices {
                let chunk = byLine[line][index]
                byLine[line][index] = Chunk(
                    id: numbered, line: chunk.line, range: chunk.range, word: chunk.word,
                    isWord: chunk.isWord, parts: chunk.parts)
                numbered += 1
            }
        }
        self.chunks = byLine.flatMap { $0 }
        chunksByLine = byLine
        var breaks: [Int] = []
        for (offset, character) in text.enumerated() where character.isNewline {
            breaks.append(offset)
        }
        lineBreaks = breaks
    }

    /// A word the recognizer broke over a line — 不気 at the foot of one column, 味 at the
    /// head of the next, or 不 / 気 / 味 one to a line — joined into one chunk when the
    /// dictionary knows the whole: the last words of a line with the first of the next,
    /// up to three on each side, the longest join the dictionary has. The joined chunk
    /// stands at the end of the line its first part was on, its range running over the
    /// break, so the picture lights both pieces and the strip reads the word whole.
    static func joinedAcrossLines(_ lines: [[Chunk]], dictionary: (any WordDictionary)?)
        -> [[Chunk]]
    {
        guard let dictionary, lines.count > 1 else { return lines }
        var lines = lines
        for boundary in 0..<(lines.count - 1) {
            let trailing = trailingWords(before: boundary, in: lines)
            let leading = Array(lines[boundary + 1].prefix(3).prefix { $0.isWord })
            guard !trailing.isEmpty, !leading.isEmpty else { continue }
            for start in trailing.indices {
                let heads = trailing[start...].map { lines[$0.line][$0.index] }
                guard let (joined, taken) = join(heads, leading, dictionary: dictionary) else {
                    continue
                }
                lines[boundary + 1].removeFirst(taken)
                for place in trailing[start...].reversed() {
                    lines[place.line].remove(at: place.index)
                }
                lines[joined.line].append(joined)
                break
            }
        }
        return lines
    }

    /// The words at the end of the lines before the break, up to three: the whole of an
    /// emptied or all-word line lets the walk go on to the line before it.
    private static func trailingWords(before boundary: Int, in lines: [[Chunk]])
        -> [(line: Int, index: Int)]
    {
        var trailing: [(line: Int, index: Int)] = []
        var line = boundary
        while line >= 0, trailing.count < 3 {
            var index = lines[line].count - 1
            while index >= 0, trailing.count < 3, lines[line][index].isWord {
                trailing.insert((line, index), at: 0)
                index -= 1
            }
            if index >= 0 { break }
            line -= 1
        }
        return trailing
    }

    /// The heads and the leading chunks as one word, when the dictionary has it and it
    /// runs over the break taking whole chunks: the joined chunk and how many of the next
    /// line's chunks it took.
    private static func join(
        _ heads: [Chunk], _ leading: [Chunk], dictionary: any WordDictionary
    ) -> (Chunk, Int)? {
        let tokens = heads.flatMap(\.word.tokens) + leading.flatMap(\.word.tokens)
        guard let first = WordFinder.segments(in: tokens, dictionary: dictionary).first,
            first.isShown, !first.word.entries.isEmpty
        else { return nil }
        let headTokens = heads.reduce(0) { $0 + $1.word.tokens.count }
        guard first.word.tokens.count > headTokens else { return nil }
        var taken = 0
        var covered = headTokens
        while taken < leading.count, covered < first.word.tokens.count {
            covered += leading[taken].word.tokens.count
            taken += 1
        }
        guard covered == first.word.tokens.count, let head = heads.first else { return nil }
        let last = leading[taken - 1]
        let joined = Chunk(
            id: head.id, line: head.line, range: head.range.lowerBound..<last.range.upperBound,
            word: first.word, isWord: true,
            parts: WordFinder.parts(of: first.word, dictionary: dictionary))
        return (joined, taken)
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
