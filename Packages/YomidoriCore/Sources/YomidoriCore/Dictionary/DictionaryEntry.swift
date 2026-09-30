import Foundation

/// Kanji forms and readings in JMdict's order, the first of each the headword;
/// `common` is JMdict's own frequency mark.
public struct DictionaryEntry: Hashable, Sendable, Identifiable {
    public struct Sense: Hashable, Sendable {
        public let partsOfSpeech: [String]
        public let glosses: [String]

        public init(partsOfSpeech: [String], glosses: [String]) {
            self.partsOfSpeech = partsOfSpeech
            self.glosses = glosses
        }
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
            let verbal = entries(conjugableAmong: candidates)
            if !verbal.isEmpty { return verbal.preferring(reading: token.reading) }
        }
        let found = entries(forAny: candidates)
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
    /// uses (見せ → 見す beside 見せる).
    public func entries(conjugableAmong candidates: [String]) -> [DictionaryEntry] {
        let found = candidates.map { self.entries(matching: $0).filter(\.isConjugable) }
            .filter { !$0.isEmpty }
        return found.first { $0.contains(where: \.common) } ?? found.first ?? []
    }

    /// The first candidate with entries wins.
    public func entries(forAny candidates: [String]) -> [DictionaryEntry] {
        candidates.lazy.map(entries(matching:)).first { !$0.isEmpty } ?? []
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
    public func preferring(reading: String) -> [DictionaryEntry] {
        filter { $0.isRead(reading) } + filter { !$0.isRead(reading) }
    }
}
