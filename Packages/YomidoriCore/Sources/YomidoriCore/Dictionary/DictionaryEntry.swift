import Foundation

/// One dictionary entry: a word, as JMdict has it. Kanji forms and readings in
/// the dictionary's order (the first of each is the headword shown), and senses,
/// each a part of speech and its glosses. `common` is JMdict's own frequency mark.
public struct DictionaryEntry: Equatable, Sendable, Identifiable {
    public struct Sense: Equatable, Sendable {
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
}
