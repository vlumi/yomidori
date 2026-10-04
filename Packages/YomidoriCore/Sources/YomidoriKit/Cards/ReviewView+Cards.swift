import YomidoriCore
import YomidoriDictionary

/// What a review reads from and writes to the cards outside answering: the dictionary's
/// glosses a card's meanings start from, and a meaning kept on a card.
extension ReviewView {
    static func glosses(of item: ReviewItem) -> [String] {
        JMdict.bundled?.entry(headword: item.card.headword, reading: item.card.reading)?.senses
            .flatMap(\.glosses) ?? []
    }

    /// A meaning added on a repeat, to the card's list alone.
    static func keep(_ meaning: String, on item: ReviewItem) -> Card? {
        guard var card = Cards.store?.card(id: item.card.id) else { return nil }
        card.addAnswer(meaning, glosses: glosses(of: item))
        Cards.write { try Cards.store?.update(card) }
        return card
    }
}
