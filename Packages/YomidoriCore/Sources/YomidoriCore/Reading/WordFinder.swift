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
}

public enum WordFinder {
    public static let longestSpan = 4

    public static func words(in tokens: [Token], dictionary: (any WordDictionary)?) -> [FoundWord] {
        segments(in: tokens, dictionary: dictionary).filter(\.isShown).map(\.word)
    }

    /// Every piece of a run of tokens in order, the words and what is no word to look up
    /// (punctuation, particles, endings), so the run can be shown whole.
    public struct Segment: Equatable, Sendable {
        public let word: FoundWord
        public let isShown: Bool
    }

    public static func segments(in tokens: [Token], dictionary: (any WordDictionary)?)
        -> [Segment]
    {
        var found: [Segment] = []
        var index = 0
        while index < tokens.count {
            guard tokens[index].isWord else {
                found.append(
                    Segment(word: FoundWord(tokens: [tokens[index]], entries: []), isShown: false))
                index += 1
                continue
            }
            let word = longestWord(from: index, in: tokens, dictionary: dictionary)
            found.append(Segment(word: word, isShown: isShown(word)))
            index += word.tokens.count
        }
        return found
    }

    private static func longestWord(
        from start: Int, in tokens: [Token], dictionary: (any WordDictionary)?
    ) -> FoundWord {
        guard let dictionary else { return FoundWord(tokens: [tokens[start]], entries: []) }
        let end = min(tokens.count, start + longestSpan)
        for stop in stride(from: end, to: start + 1, by: -1) {
            let span = Array(tokens[start..<stop])
            guard span.allSatisfy(\.isWord) else { continue }
            let surface = span.map(\.surface).joined()
            var entries = dictionary.entries(forAny: Deinflector.candidates(for: surface))
            // Endings and particles side by side spell many a word in kana (た + が is 箍 or 誰が,
            // し + た is 下); a join of kana alone counts only as what is first of all an
            // expression, かもしれない.
            if Kana.isKana(surface) {
                entries = entries.filter { $0.senses.first?.partsOfSpeech.contains("exp") == true }
            } else if entries.isEmpty {
                // A verb with its ending cut off as a word (頼み + たい): the verb, whole.
                entries = dictionary.entries(conjugatedFrom: surface)
            }
            if !entries.isEmpty {
                return FoundWord(
                    tokens: span, entries: entries.preferring(reading: span.map(\.reading).joined())
                )
            }
        }
        // Looked up only when no longer word was found.
        return FoundWord(tokens: [tokens[start]], entries: dictionary.entries(for: tokens[start]))
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
