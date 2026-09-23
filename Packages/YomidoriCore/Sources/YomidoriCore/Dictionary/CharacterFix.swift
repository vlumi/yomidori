/// A character that could stand where the recognizer misread one: the words in the
/// dictionary spelled like the rest of the word, and what they have in that place.
public struct CharacterFix: Equatable, Sendable {
    public let character: String
    public let entry: DictionaryEntry

    public init(character: String, entry: DictionaryEntry) {
        self.character = character
        self.entry = entry
    }

    /// For the character at `index` of `surface`, common words first, each character once.
    /// A cut stem (頷い) is also tried as its dictionary forms, which share its start.
    public static func candidates(
        for surface: String, at index: Int, dictionary: any WordDictionary, limit: Int = 12
    ) -> [CharacterFix] {
        let characters = Array(surface)
        guard characters.indices.contains(index) else { return [] }
        let original = String(characters[index])
        var forms = [surface]
        for form in Deinflector.candidates(for: surface) where !forms.contains(form) {
            forms.append(form)
        }
        var seen: Set<String> = [original]
        var found: [CharacterFix] = []
        for form in forms {
            let spelled = Array(form)
            guard spelled.count > index, spelled.prefix(index) == characters.prefix(index) else {
                continue
            }
            for entry in dictionary.entries(spelledLike: form, anyCharacterAt: index, limit: limit)
            {
                for kanji in entry.kanji where kanji.count == spelled.count {
                    let letters = Array(kanji)
                    let fits = letters.indices.allSatisfy {
                        $0 == index || letters[$0] == spelled[$0]
                    }
                    let character = String(letters[index])
                    if fits, seen.insert(character).inserted {
                        found.append(CharacterFix(character: character, entry: entry))
                    }
                }
            }
        }
        return Array(found.prefix(limit))
    }
}
