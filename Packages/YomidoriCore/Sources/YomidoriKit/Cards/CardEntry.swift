import YomidoriCore
import YomidoriDictionary

extension JMdict {
    /// The entry a card was kept from: by its id, since a card is headed as the book spells
    /// the word (戰爭, こと) and the dictionary lists it otherwise; by its word for a card
    /// kept without one.
    func entry(of card: Card) -> DictionaryEntry? {
        card.entryID.flatMap(entry(withID:))
            ?? entry(headword: card.headword, reading: card.reading)
    }
}
