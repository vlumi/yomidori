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

    /// What a card of the word is headed by: the dictionary's headword, else the dictionary
    /// form, else the word as it stands on the page.
    public var cardHeadword: String { entries.first?.headword ?? dictionaryForm ?? surface }
    /// What a card of the word reads: the dictionary's first reading, else the page's.
    public var cardReading: String { Kana.hiragana(entries.first?.readings.first ?? reading) }
    /// The key a card of the word is kept under (`WordKey`).
    public var wordKey: String { WordKey.of(headword: cardHeadword, reading: cardReading) }
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

    /// The words a joined word is made of, each one to look up or keep by itself: トロイ and
    /// 木馬 in トロイの木馬, 蛍光 and 灯 in 蛍光灯. None for a word of one token, or where the
    /// parts are no words of their own.
    public static func parts(of word: FoundWord, dictionary: (any WordDictionary)?)
        -> [FoundWord]
    {
        guard word.tokens.count > 1, let dictionary else { return [] }
        let verbal = word.entries.first?.isConjugable == true
        return segments(in: word.tokens, dictionary: dictionary, span: word.tokens.count - 1)
            .filter(\.isShown).map(\.word)
            // A piece in hiragana alone is an ending or a particle of the whole (つか in
            // 見当がつかぬ), and what the dictionary spells that way is some other word.
            .filter { !$0.surface.unicodeScalars.allSatisfy(isHiragana) }
            .map { part in
                // In a verb joined from stems (走り + 出し), each stem is its verb, not the
                // noun spelled the same.
                guard verbal, Deinflector.isStem(part.surface) else { return part }
                let verbs = dictionary.entries(
                    conjugableAmong: Deinflector.candidates(for: part.surface))
                return verbs.isEmpty
                    ? part
                    : FoundWord(
                        tokens: part.tokens, entries: verbs.preferring(reading: part.reading))
            }
    }

    private static func isHiragana(_ scalar: Unicode.Scalar) -> Bool {
        (0x3040...0x309F).contains(scalar.value)
    }

    /// `span` is the most tokens one word may join; fewer than a whole word's own to cut
    /// it into its parts.
    public static func segments(
        in tokens: [Token], dictionary: (any WordDictionary)?, span: Int = longestSpan
    ) -> [Segment] {
        var found: [Segment] = []
        var index = 0
        // After a stem and its ending, the endings that follow are the same inflection
        // (見 + て + い + た), not words: させ is not 差す, いる not 射る, しまっ not 仕舞う.
        var inflecting = false
        while index < tokens.count {
            let token = tokens[index]
            guard token.isWord else {
                found.append(Segment(word: FoundWord(tokens: [token], entries: []), isShown: false))
                inflecting = false
                index += 1
                continue
            }
            if inflecting, Kana.isKana(token.surface),
                Deinflector.continuesInflection(token.surface)
            {
                found.append(Segment(word: FoundWord(tokens: [token], entries: []), isShown: false))
                index += 1
                continue
            }
            let word = longestWord(from: index, in: tokens, dictionary: dictionary, span: span)
            found.append(Segment(word: word, isShown: isShown(word)))
            index += word.tokens.count
            inflecting = isInflected(word.tokens, in: tokens, endingAt: index)
        }
        return found
    }

    private static func longestWord(
        from start: Int, in tokens: [Token], dictionary: (any WordDictionary)?, span: Int
    ) -> FoundWord {
        guard let dictionary else { return FoundWord(tokens: [tokens[start]], entries: []) }
        let end = min(tokens.count, start + max(span, 1))
        for stop in stride(from: end, to: start + 1, by: -1) {
            let span = Array(tokens[start..<stop])
            guard span.allSatisfy(\.isWord) else { continue }
            let surface = span.map(\.surface).joined()
            let candidates = Deinflector.candidates(for: surface)
            var entries = dictionary.entries(forAny: candidates)
            // A stem with its ending cut off after it (吹き出し + た, 揺すり + ながら) is a verb
            // or an adjective, whatever noun the dictionary spells the same way.
            if isInflected(span, in: tokens, endingAt: stop), !Kana.isKana(surface) {
                let verbal = dictionary.entries(conjugableAmong: candidates)
                if !verbal.isEmpty { entries = verbal }
            }
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
        return FoundWord(
            tokens: [tokens[start]],
            entries: dictionary.entries(
                for: tokens[start],
                inflected: isInflected([tokens[start]], in: tokens, endingAt: start + 1)))
    }

    /// The span is a stem, and the token after it is an ending cut from it.
    private static func isInflected(_ span: [Token], in tokens: [Token], endingAt next: Int)
        -> Bool
    {
        guard next < tokens.count, let last = span.last, Deinflector.isStem(last.surface)
        else { return false }
        return Deinflector.isEnding(tokens[next].surface, after: last.surface)
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
