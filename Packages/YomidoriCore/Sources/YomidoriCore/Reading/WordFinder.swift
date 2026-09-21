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

    /// A lone kana is a particle or an auxiliary, not a word to look up.
    private static func isShown(_ word: FoundWord) -> Bool {
        let surface = word.surface
        return surface.count > 1 || !Kana.isKana(surface)
    }
}
