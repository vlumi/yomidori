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
    /// Kana or kanji as a prefix of headwords and readings; anything else searches the glosses.
    func search(_ query: String, limit: Int) -> [DictionaryEntry]
    func kanji(_ literal: String) -> KanjiEntry?
    /// Entries with a kanji form that contains `text` and is not `text`, common words first.
    func entries(containing text: String, limit: Int) -> [DictionaryEntry]
}

extension WordDictionary {
    public func kanji(_ literal: String) -> KanjiEntry? { nil }
    public func entries(containing text: String, limit: Int) -> [DictionaryEntry] { [] }

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
    /// the first candidate with entries wins.
    public func entries(for token: Token) -> [DictionaryEntry] {
        entries(
            forAny: [token.dictionaryForm].compactMap { $0 }
                + Deinflector.candidates(for: token.surface) + [token.reading])
    }

    /// The first candidate with entries wins.
    public func entries(forAny candidates: [String]) -> [DictionaryEntry] {
        candidates.lazy.map(entries(matching:)).first { !$0.isEmpty } ?? []
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
