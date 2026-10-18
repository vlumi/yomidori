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

    /// The dictionary's headword for a card headed otherwise (事 for こと, 戦争 for 戰爭), to
    /// show beside it; nil where the two are the same.
    func listedForm(of card: Card) -> String? {
        entry(of: card)?.headword.nonEmpty(unless: card.headword)
    }
}

extension String {
    /// The string, unless it is `other` or empty.
    func nonEmpty(unless other: String) -> String? {
        isEmpty || self == other ? nil : self
    }
}
