import Foundation

/// One dictionary entry: a word, as JMdict has it. Kanji forms and readings in
/// the dictionary's order (the first of each is the headword shown), and senses,
/// each a part of speech and its glosses. `common` is JMdict's own frequency mark.
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

    /// The form to show for the word: its first kanji form, or its reading when it has none.
    public var headword: String {
        kanji.first ?? readings.first ?? ""
    }
}

/// Looks words up. One implementation reads the bundled JMdict; tests use a sliver of it.
public protocol WordDictionary {
    /// Entries whose kanji form or reading is exactly `text`, common words first.
    func entries(matching text: String) -> [DictionaryEntry]
    /// The pitch accents recorded for a headword read a given way, the usual one first;
    /// empty when the accent data has no such word.
    func pitchAccents(for headword: String, reading: String) -> [PitchAccent]
    /// Typed search: kana or kanji finds headwords and readings that start with it,
    /// anything else searches the English glosses. Common words first, at most `limit`.
    func search(_ query: String, limit: Int) -> [DictionaryEntry]
}

extension WordDictionary {
    /// The entry for a word read a given way: the headword's entries, the first whose
    /// readings include the reading, katakana counting as its hiragana.
    public func entry(headword: String, reading: String) -> DictionaryEntry? {
        entries(matching: headword).first { $0.readings.map(Kana.hiragana).contains(reading) }
    }

    /// The entries for a word as the tokenizer cut it: the tokenizer's dictionary form
    /// first, then the word as it stands and the forms its stem deinflects to, then its
    /// reading; the first candidate with any entries wins.
    public func entries(for token: Token) -> [DictionaryEntry] {
        let candidates =
            [token.dictionaryForm].compactMap { $0 } + Deinflector.candidates(for: token.surface)
            + [token.reading]
        return candidates.lazy.map(entries(matching:)).first { !$0.isEmpty } ?? []
    }

    /// The usual pitch accent of an entry, by its headword and first reading.
    public func pitchAccent(of entry: DictionaryEntry) -> PitchAccent? {
        guard let reading = entry.readings.first else { return nil }
        return pitchAccents(for: entry.headword, reading: Kana.hiragana(reading)).first
    }
}

/// What a typed query is asking for.
public enum SearchQuery {
    public enum Kind: Equatable {
        case japanese
        case gloss
        case empty
    }

    /// Japanese when the query has any kana or kanji; otherwise a gloss search.
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
