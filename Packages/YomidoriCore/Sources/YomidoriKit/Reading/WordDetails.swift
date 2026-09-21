import Foundation
import YomidoriCore
import YomidoriDictionary

/// What the dictionary has around a word, gathered off the main thread: the entry,
/// its kanji, the words read the same way, and the words it appears in.
struct WordDetails {
    var entry: DictionaryEntry?
    var accents: [String: [PitchAccent]] = [:]
    var kanji: [KanjiEntry] = []
    var homophones: [DictionaryEntry] = []
    var containing: [DictionaryEntry] = []

    static func load(headword: String, reading: String, entry: DictionaryEntry? = nil) async
        -> WordDetails
    {
        await Task.detached(priority: .userInitiated) {
            guard let dictionary = JMdict.bundled else { return WordDetails() }
            var details = WordDetails()
            details.entry = entry ?? dictionary.entry(headword: headword, reading: reading)
            for reading in details.entry?.readings ?? [reading] {
                let kana = Kana.hiragana(reading)
                details.accents[kana] = dictionary.pitchAccents(for: headword, reading: kana)
            }
            details.kanji = KanjiEntry.literals(in: headword).compactMap(dictionary.kanji)
            details.homophones = details.entry.map(dictionary.homophones) ?? []
            details.containing = dictionary.entries(containing: headword, limit: 40)
            return details
        }.value
    }

    func accent(of reading: String) -> PitchAccent? {
        accents[Kana.hiragana(reading)]?.first
    }

    /// Another entry's usual accent, looked up on the spot; the cache is this word's own.
    func accent(ofEntry entry: DictionaryEntry) -> PitchAccent? {
        JMdict.bundled?.pitchAccent(of: entry)
    }
}
