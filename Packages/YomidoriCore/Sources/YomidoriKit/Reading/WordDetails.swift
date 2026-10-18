import Foundation
import YomidoriCore
import YomidoriDictionary

/// What the dictionary has around a word, gathered off the main thread: the entry,
/// its kanji, the words read the same way, and the words it appears in.
struct WordDetails {
    var entry: DictionaryEntry?
    var accents: [String: [PitchAccent]] = [:]
    /// The pitch worked out for the word, where the dictionary has no accent for it.
    var estimate: [PitchPhrase] = []
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
            // The accents and the words around it by the dictionary's spelling; the kanji as
            // the word is written (戰 in 戰爭).
            let listed = details.entry?.headword ?? headword
            for reading in details.entry?.readings ?? [reading] {
                let kana = Kana.hiragana(reading)
                details.accents[kana] = dictionary.pitchAccents(for: listed, reading: kana)
            }
            if details.accents.values.allSatisfy(\.isEmpty) {
                details.estimate = dictionary.estimatedPitch(
                    for: listed, reading: details.entry?.readings.first ?? reading)
            }
            details.kanji = KanjiEntry.literals(in: headword).compactMap(dictionary.kanji)
            details.homophones = details.entry.map(dictionary.homophones) ?? []
            details.containing = dictionary.entries(containing: listed, limit: 40)
            return details
        }.value
    }

    /// A card's, its entry found by the id it was kept with.
    static func load(card: Card) async -> WordDetails {
        let entry = await Task.detached { JMdict.bundled?.entry(of: card) }.value
        return await load(headword: card.headword, reading: card.reading, entry: entry)
    }

    func accent(of reading: String) -> PitchAccent? {
        accents[Kana.hiragana(reading)]?.first
    }

    /// Another entry's usual accent, looked up on the spot; the cache is this word's own.
    func accent(ofEntry entry: DictionaryEntry) -> PitchAccent? {
        JMdict.bundled?.pitchAccent(of: entry)
    }
}
