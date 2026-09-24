import Foundation

/// A word as found in a run of tokens: one token, or several the dictionary knows as one.
public struct FoundWord: Equatable, Sendable {
    public let tokens: [Token]
    public let entries: [DictionaryEntry]

    public init(tokens: [Token], entries: [DictionaryEntry]) {
        precondition(!tokens.isEmpty)
        self.tokens = tokens
        self.entries = entries
    }

    public var surface: String { tokens.map(\.surface).joined() }
    public var reading: String { tokens.map(\.reading).joined() }
    public var dictionaryForm: String? { tokens.count == 1 ? tokens[0].dictionaryForm : nil }
    public var first: Token { tokens[0] }

    /// The same word spelled by the tokens of `line`, or nil when the line lacks it.
    public func aligned(to line: [Token]) -> FoundWord? {
        let surfaces = tokens.map(\.surface)
        guard line.count >= surfaces.count else { return nil }
        for start in 0...(line.count - surfaces.count) {
            let run = line[start..<start + surfaces.count]
            if run.map(\.surface) == surfaces {
                return FoundWord(tokens: Array(run), entries: entries)
            }
        }
        return nil
    }
}

public enum WordFinder {
    public static let longestSpan = 4

    /// The tokens of `line` that overlap `range`, counted in characters of `text`, the line
    /// the tokens were cut from.
    public static func tokens(_ line: [Token], overlapping range: Range<Int>, in text: String)
        -> [Token]
    {
        line.filter { token in
            let start = text.distance(from: text.startIndex, to: token.range.lowerBound)
            let end = text.distance(from: text.startIndex, to: token.range.upperBound)
            return start < range.upperBound && end > range.lowerBound
        }
    }

    /// The word covering the character at `offset` of `text`, the line the tokens were cut from,
    /// with its range there in characters; nil on punctuation or what is no word to look up.
    public static func word(
        atCharacter offset: Int, in tokens: [Token], text: String, dictionary: (any WordDictionary)?
    ) -> (word: FoundWord, range: Range<Int>)? {
        for word in words(in: tokens, dictionary: dictionary) {
            let start = text.distance(from: text.startIndex, to: word.tokens[0].range.lowerBound)
            let end = text.distance(
                from: text.startIndex, to: word.tokens[word.tokens.count - 1].range.upperBound)
            if (start..<end).contains(offset) { return (word, start..<end) }
        }
        return nil
    }

    public static func words(in tokens: [Token], dictionary: (any WordDictionary)?) -> [FoundWord] {
        var found: [FoundWord] = []
        var index = 0
        while index < tokens.count {
            guard tokens[index].isWord else {
                index += 1
                continue
            }
            let word = longestWord(from: index, in: tokens, dictionary: dictionary)
            if isShown(word) {
                found.append(word)
            }
            index += word.tokens.count
        }
        return found
    }

    private static func longestWord(
        from start: Int, in tokens: [Token], dictionary: (any WordDictionary)?
    ) -> FoundWord {
        let single = FoundWord(
            tokens: [tokens[start]], entries: dictionary?.entries(for: tokens[start]) ?? [])
        guard let dictionary else { return single }
        let end = min(tokens.count, start + longestSpan)
        for stop in stride(from: end, to: start + 1, by: -1) {
            let span = Array(tokens[start..<stop])
            guard span.allSatisfy(\.isWord) else { continue }
            let surface = span.map(\.surface).joined()
            let entries = dictionary.entries(forAny: Deinflector.candidates(for: surface))
            if !entries.isEmpty {
                return FoundWord(tokens: span, entries: entries)
            }
        }
        return single
    }

    /// Kana alone with nothing in the dictionary is a particle, an ending or a fragment of
    /// a misread word; a word the dictionary marks as a particle or an auxiliary (ません,
    /// から) is not one to look up either.
    private static func isShown(_ word: FoundWord) -> Bool {
        if Kana.isKana(word.surface) {
            return word.surface.count > 1 && !word.entries.isEmpty
                && !word.entries.allSatisfy(\.isFunctionWord)
        }
        return word.entries.isEmpty || !word.entries.allSatisfy(\.isFunctionWord)
    }
}
