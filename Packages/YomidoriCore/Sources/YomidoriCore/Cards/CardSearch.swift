import Foundation

/// A card found by what is typed: kana in either script anywhere in its reading or its
/// headword, kanji in its headword, or part of one of its meanings, case and accents aside.
public enum CardSearch {
    public static func matches(_ card: Card, _ query: String, meanings: [String]) -> Bool {
        let typed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !typed.isEmpty else { return true }
        let kana = Kana.hiragana(typed)
        if Kana.hiragana(card.headword).contains(kana) || Kana.hiragana(card.reading).contains(kana)
        {
            return true
        }
        return meanings.contains {
            $0.range(of: typed, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }
}
