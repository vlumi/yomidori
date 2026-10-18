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
    /// The word as the page spells it, where that differs from what was looked up (但シ
    /// for 但し).
    public var written: String { tokens.map { $0.written ?? $0.surface }.joined() }

    /// The form the dictionary lists the word under when the page has it inflected: the
    /// tokenizer's for one token (眩ん → 眩む), and for a word joined from several, the
    /// entry's form the stem was deinflected to (目が眩ん → 目が眩む). Nil when the page
    /// already spells it as the dictionary does.
    public var dictionaryForm: String? {
        guard tokens.count > 1 else { return tokens[0].dictionaryForm }
        guard let entry = entries.first else { return nil }
        let forms = Deinflector.candidates(for: surface).dropFirst()
        return (entry.kanji + entry.readings).first { forms.contains($0) }
    }

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
        while index < tokens.count {
            let token = tokens[index]
            guard token.isWord else {
                found.append(Segment(word: FoundWord(tokens: [token], entries: []), isShown: false))
                index += 1
                continue
            }
            let word = longestWord(from: index, in: tokens, dictionary: dictionary, span: span)
            found.append(Segment(word: word, isShown: isShown(word)))
            index += word.tokens.count
            // After a stem and its ending, the endings that follow are the same inflection
            // (見 + て + い + た), not words: させ is not 差す, いる not 射る, しまっ not 仕舞う.
            for ending in endings(from: index, after: word.tokens, in: tokens) {
                found.append(
                    Segment(word: FoundWord(tokens: [ending], entries: []), isShown: false))
                index += 1
            }
        }
        return found
    }

    /// The endings a tokenizer cut off after a word's stem, as they follow it in the run:
    /// で and いる after 恨ん, れ, て, い and た after 照らさ. None after a word the page
    /// spells as the dictionary does.
    public static func endings(after word: FoundWord, in tokens: [Token]) -> [Token] {
        guard let last = word.tokens.last,
            let index = tokens.firstIndex(where: { $0.range == last.range })
        else { return [] }
        return endings(from: index + 1, after: word.tokens, in: tokens)
    }

    private static func endings(from start: Int, after stem: [Token], in tokens: [Token])
        -> [Token]
    {
        guard isInflected(stem, in: tokens, endingAt: start) else { return [] }
        var endings: [Token] = []
        var index = start
        while index < tokens.count, tokens[index].isWord, Kana.isKana(tokens[index].surface),
            Deinflector.continuesInflection(tokens[index].surface)
        {
            endings.append(tokens[index])
            index += 1
        }
        return endings
    }

    /// The word's form on the page, as a card marks it in the sentence: a verb or an
    /// adjective whole, with the endings cut off after its stem (恨んでいる, 頼みたい), and a
    /// する noun without its する (黙認 in 黙認します), since the noun is the word and する
    /// a verb of its own.
    /// As the page prints it: the surface read in hiragana or modern kana (より for ヨリ,
    /// 思う for 思ふ) is the page's own spelling again, one kana for one.
    public static func pageForm(of word: FoundWord, in tokens: [Token]) -> String {
        let surface = word.surface
        if let entry = word.entries.first {
            let forms = entry.kanji + entry.readings
            if !forms.contains(surface),
                let noun = forms.first(where: { form in
                    surface.hasPrefix(form)
                        && Deinflector.isSuruForm(String(surface.dropFirst(form.count)))
                })
            {
                return String(word.written.prefix(noun.count))
            }
        }
        return word.written
            + endings(after: word, in: tokens).map { $0.written ?? $0.surface }.joined()
    }

    private static func longestWord(
        from start: Int, in tokens: [Token], dictionary: (any WordDictionary)?, span: Int
    ) -> FoundWord {
        guard let dictionary else { return FoundWord(tokens: [tokens[start]], entries: []) }
        let end = min(tokens.count, start + max(span, 1))
        for stop in stride(from: end, to: start + 1, by: -1) {
            let written = Array(tokens[start..<stop])
            guard written.allSatisfy(\.isWord) else { continue }
            let modern = modern(written, before: tokens, at: stop)
            for span in [written] + [modern].compactMap({ $0 }) {
                let entries = lookUp(span, in: tokens, endingAt: stop, dictionary: dictionary)
                if !entries.isEmpty {
                    return FoundWord(
                        tokens: span,
                        entries: entries.preferring(reading: span.map(\.reading).joined()))
                }
            }
        }
        let token = tokens[start]
        let inflected = isInflected([token], in: tokens, endingAt: start + 1)
        // A word of one token in prewar kana (思ふ), before its reading stands in for it.
        if let modern = modern([token], before: tokens, at: start + 1) {
            let entries = lookUp(modern, in: tokens, endingAt: start + 1, dictionary: dictionary)
            if !entries.isEmpty {
                return FoundWord(
                    tokens: modern, entries: entries.preferring(reading: modern[0].reading))
            }
        }
        // Looked up only when no longer word was found.
        return FoundWord(
            tokens: [token], entries: dictionary.entries(for: token, inflected: inflected))
    }

    /// The span in modern kana, each token as long as before and keeping the page's
    /// spelling as `written`; nil where prewar kana changes nothing.
    private static func modern(_ span: [Token], before tokens: [Token], at next: Int)
        -> [Token]?
    {
        let surface = span.map(\.surface).joined()
        let following = next < tokens.count ? tokens[next].surface : nil
        guard let modern = HistoricalKana.modern(surface, before: following) else { return nil }
        var rest = Substring(modern)
        return span.map { token in
            let piece = String(rest.prefix(token.surface.count))
            rest = rest.dropFirst(token.surface.count)
            return Token(
                surface: piece,
                reading: HistoricalKana.modern(token.reading) ?? token.reading,
                range: token.range, isWord: token.isWord,
                written: token.written ?? (piece == token.surface ? nil : token.surface))
        }
    }

    /// The entries for a run of tokens taken as one word, or none.
    private static func lookUp(
        _ span: [Token], in tokens: [Token], endingAt stop: Int, dictionary: any WordDictionary
    ) -> [DictionaryEntry] {
        let surface = span.map(\.surface).joined()
        let candidates = Deinflector.candidates(for: surface)
        // The run as written, any word; deinflected, verbs and adjectives alone.
        var entries = dictionary.entries(
            forAny: [surface], orConjugableAmong: Array(candidates.dropFirst()))
        // A stem with its ending cut off after it (吹き出し + た, 揺すり + ながら) is a verb
        // or an adjective, whatever noun the dictionary spells the same way.
        if isInflected(span, in: tokens, endingAt: stop), !Kana.isKana(surface) {
            let verbal = dictionary.entries(conjugableAmong: candidates)
            if !verbal.isEmpty { entries = verbal }
        }
        // Endings and particles side by side spell many a word in kana (た + が is 箍 or 誰が,
        // し + た is 下); a join of kana alone counts only as what is first of all an
        // expression, かもしれない.
        if Kana.isKana(surface), span.count > 1 {
            entries = entries.filter { $0.senses.first?.partsOfSpeech.contains("exp") == true }
        } else if entries.isEmpty, !Kana.isKana(surface) {
            // A verb with its ending cut off as a word (頼み + たい): the verb, whole.
            entries = dictionary.entries(conjugatedFrom: surface)
        }
        return entries
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
