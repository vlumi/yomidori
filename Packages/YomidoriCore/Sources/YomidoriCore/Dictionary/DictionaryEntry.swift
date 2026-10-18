import Foundation

/// Kanji forms and readings in JMdict's order, the first of each the headword;
/// `common` is JMdict's own frequency mark.
public struct DictionaryEntry: Hashable, Sendable, Identifiable {
    public struct Sense: Hashable, Sendable {
        public let partsOfSpeech: [String]
        public let glosses: [String]
        /// JMdict's notes on the sense: uk (usually written in kana), arch, obs, col, …
        public let misc: [String]

        public init(partsOfSpeech: [String], glosses: [String], misc: [String] = []) {
            self.partsOfSpeech = partsOfSpeech
            self.glosses = glosses
            self.misc = misc
        }

        /// The sense is usually written in kana, its kanji seldom seen (居る, 為る).
        public var isUsuallyKana: Bool { misc.contains("uk") }
    }

    public let id: Int
    public let kanji: [String]
    public let readings: [String]
    public let senses: [Sense]
    public let common: Bool

    public init(id: Int, kanji: [String], readings: [String], senses: [Sense], common: Bool) {
        self.id = id
        self.kanji = kanji
        self.readings = readings
        self.senses = senses
        self.common = common
    }

    public var headword: String {
        kanji.first ?? readings.first ?? ""
    }

    /// A particle, an auxiliary or the copula, by JMdict's own marks: every marked sense is
    /// one of those.
    /// A verb, a する noun or an i-adjective: a word endings can be put on.
    public var isConjugable: Bool {
        senses.contains { sense in
            sense.partsOfSpeech.contains { pos in
                pos == "adj-i" || (pos.hasPrefix("v") && !["vi", "vt"].contains(pos))
            }
        }
    }

    /// Whether the word is read `reading` (katakana counting as hiragana).
    public func isRead(_ reading: String) -> Bool {
        let wanted = Kana.hiragana(reading)
        return readings.contains { Kana.hiragana($0) == wanted }
    }

    /// Whether `form` is one of the word's kanji forms, in old kanji (戰爭) as in modern.
    public func isSpelled(_ form: String) -> Bool {
        kanji.contains(form) || OldKanji.modern(form).map(kanji.contains) == true
    }

    /// The word is written in kana: it has no kanji, or its first sense is usually written
    /// without them. いる on a page is 居る, not 射る; いい is いい, not 謂.
    public var isUsuallyKana: Bool { kanji.isEmpty || senses.first?.isUsuallyKana == true }

    public var isFunctionWord: Bool {
        let function: Set<String> = ["prt", "aux", "aux-v", "aux-adj", "cop"]
        let marked = senses.filter { !$0.partsOfSpeech.isEmpty }
        return !marked.isEmpty
            && marked.allSatisfy { $0.partsOfSpeech.allSatisfy(function.contains) }
    }
}

public protocol WordDictionary {
    /// Exact kanji form or reading, common words first.
    func entries(matching text: String) -> [DictionaryEntry]
    func pitchAccents(for headword: String, reading: String) -> [PitchAccent]
    /// The pitch worked out for a word the accent dictionary lacks, an expression's phrase by
    /// phrase; to show as an estimate, never to ask. None where there is no estimate.
    func estimatedPitch(for headword: String, reading: String) -> [PitchPhrase]
    /// Kana or kanji as a prefix of headwords and readings; anything else searches the glosses.
    func search(_ query: String, limit: Int) -> [DictionaryEntry]
    func kanji(_ literal: String) -> KanjiEntry?
    /// Entries with a kanji form that contains `text` and is not `text`, common words first.
    func entries(containing text: String, limit: Int) -> [DictionaryEntry]
    /// Entries with a kanji form spelled as `form` except at `index`, where any one character
    /// stands; common words first.
    func entries(spelledLike form: String, anyCharacterAt index: Int, limit: Int)
        -> [DictionaryEntry]
    /// Every part kanji are built from.
    func kanjiParts() -> [KanjiPart]
    /// The kanji built from all of `parts` (by `KanjiPart.component`), fewest strokes first.
    func kanji(withParts parts: [String], limit: Int) -> [String]
    /// The parts found together with all of `parts` in some kanji, so adding one of them
    /// still leaves a kanji to find.
    func parts(foundWith parts: [String]) -> Set<String>
}

extension WordDictionary {
    public func kanji(_ literal: String) -> KanjiEntry? { nil }
    public func entries(containing text: String, limit: Int) -> [DictionaryEntry] { [] }
    public func entries(spelledLike form: String, anyCharacterAt index: Int, limit: Int)
        -> [DictionaryEntry]
    { [] }
    public func kanjiParts() -> [KanjiPart] { [] }
    public func kanji(withParts parts: [String], limit: Int) -> [String] { [] }
    public func parts(foundWith parts: [String]) -> Set<String> { [] }

    /// Other words read the same way, written in kanji, common first.
    public func homophones(of entry: DictionaryEntry) -> [DictionaryEntry] {
        guard let reading = entry.readings.first else { return [] }
        return entries(matching: Kana.hiragana(reading)).filter {
            $0.id != entry.id && !$0.kanji.isEmpty
        }
    }

    /// Katakana readings count as their hiragana.
    public func entry(headword: String, reading: String) -> DictionaryEntry? {
        entries(matching: headword).first { $0.readings.map(Kana.hiragana).contains(reading) }
    }

    /// The tokenizer's dictionary form, then the word and its deinflections, then its reading;
    /// the first candidate with entries wins. A stem with an ending after it is a verb or an
    /// adjective, and its deinflections' conjugable entries come before the word as it
    /// stands, which may spell a noun (吹き出し).
    public func entries(for token: Token, inflected: Bool = false) -> [DictionaryEntry] {
        let candidates =
            [token.dictionaryForm].compactMap { $0 } + Deinflector.candidates(for: token.surface)
        if inflected, !Kana.isKana(token.surface) {
            let verbal = entries(conjugableAmong: candidates, reading: token.reading)
            if !verbal.isEmpty { return verbal.preferring(reading: token.reading) }
        }
        // As written, or as the tokenizer names it: any word. Deinflected: a verb or an
        // adjective only — にけ is no 肉 for ending in け.
        let found = entries(
            forAny: [token.dictionaryForm, token.surface].compactMap { $0 },
            orConjugableAmong: Array(Deinflector.candidates(for: token.surface).dropFirst()),
            reading: token.reading)
        if !found.isEmpty { return found.preferring(reading: token.reading) }
        if !Kana.isKana(token.surface) {
            let conjugated = entries(conjugatedFrom: token.surface)
            if !conjugated.isEmpty { return conjugated }
        }
        return entries(matching: token.reading)
    }

    /// A verb or adjective under an ending (認めよう → 認める); nothing else is taken, so a
    /// noun spelled like the stem (頼み) doesn't stand in for the verb.
    public func entries(conjugatedFrom surface: String) -> [DictionaryEntry] {
        Deinflector.conjugated(surface).lazy
            .map { self.entries(matching: $0).filter(\.isConjugable) }
            .first { !$0.isEmpty } ?? []
    }

    /// The first candidate with a common conjugable entry, else the first with any; the
    /// conjugable entries alone. Common first, since the rows also spell verbs no one
    /// uses (見せ → 見す beside 見せる). Where the page's `reading` is known, a candidate
    /// read so comes first: 終っ read おわっ is 終わる, though 終う spells しまう too.
    public func entries(conjugableAmong candidates: [String], reading: String? = nil)
        -> [DictionaryEntry]
    {
        let found = candidates.map { self.entries(matching: $0).filter(\.isConjugable) }
            .filter { !$0.isEmpty }
        if let stem = Self.stem(of: reading) {
            let read = found.filter { group in
                group.contains { $0.readings.contains { Kana.hiragana($0).hasPrefix(stem) } }
            }
            if let group = read.first(where: { $0.contains(where: \.common) }) ?? read.first {
                return group
            }
        }
        return found.first { $0.contains(where: \.common) } ?? found.first ?? []
    }

    /// A stem's reading without its last kana, the one that changes as the word conjugates
    /// (おわっ → おわ, いっ → い); nil where nothing would be left.
    private static func stem(of reading: String?) -> String? {
        guard let reading, reading.count > 1, Kana.isKana(reading) else { return nil }
        return String(Kana.hiragana(reading).dropLast())
    }

    /// The first candidate with entries wins.
    public func entries(forAny candidates: [String]) -> [DictionaryEntry] {
        candidates.lazy.map(entries(matching:)).first { !$0.isEmpty } ?? []
    }

    /// The word as it stands, any entry; failing that, the forms a stem could come from,
    /// verbs and adjectives alone: a stem is a stem of something that conjugates, and a
    /// noun spelled like one of its forms is another word.
    public func entries(
        forAny exact: [String], orConjugableAmong forms: [String], reading: String? = nil
    ) -> [DictionaryEntry] {
        let found = entries(forAny: exact)
        return found.isEmpty ? entries(conjugableAmong: forms, reading: reading) : found
    }

    public func estimatedPitch(for headword: String, reading: String) -> [PitchPhrase] { [] }

    /// The entry's estimate, for where it has no accent of the dictionary's.
    public func estimatedPitch(of entry: DictionaryEntry) -> [PitchPhrase] {
        guard let reading = entry.readings.first else { return [] }
        return estimatedPitch(for: entry.headword, reading: reading)
    }

    public func pitchAccent(of entry: DictionaryEntry) -> PitchAccent? {
        guard let reading = entry.readings.first else { return nil }
        return pitchAccents(for: entry.headword, reading: Kana.hiragana(reading)).first
    }
}

public enum SearchQuery {
    public enum Kind: Equatable {
        case japanese
        case gloss
        case empty
    }

    public static func kind(of query: String) -> Kind {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }
        let japanese = trimmed.unicodeScalars.contains { scalar in
            (0x3040...0x30FF).contains(scalar.value) || (0x3400...0x9FFF).contains(scalar.value)
                || (0xF900...0xFAFF).contains(scalar.value)
        }
        return japanese ? .japanese : .gloss
    }
}

extension Array where Element == DictionaryEntry {
    /// The entries read as the tokenizer read the word first (本 as ほん before 元 as もと),
    /// the dictionary's order kept otherwise.
    /// For a word the page writes in kana, the common entries usually written so first,
    /// each group in its order: いる is 居る or 要る before 射る and 入る. Common ones alone,
    /// since JMdict marks many a rare plant and animal so too (野老 for ところ, 鴇 for とき).
    public func preferringKana(for surface: String) -> [DictionaryEntry] {
        guard Kana.isKana(surface) else { return self }
        let first = filter { $0.common && $0.isUsuallyKana }
        return first + filter { !($0.common && $0.isUsuallyKana) }
    }

    public func preferring(reading: String) -> [DictionaryEntry] {
        filter { $0.isRead(reading) } + filter { !$0.isRead(reading) }
    }
}

extension DictionaryEntry {
    /// The entry's first reading in hiragana: the reading a card is keyed and shown by.
    public var hiraganaReading: String { Kana.hiragana(readings.first ?? "") }

    /// The key a card of this entry is kept under (`WordKey`).
    public var wordKey: String { WordKey.of(headword: headword, reading: hiraganaReading) }
}
