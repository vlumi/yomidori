import Foundation

/// A word as the tokenizer cut it, with its reading. The reading is hiragana, the
/// form a reader expects; punctuation and spaces are tokens too, so a sentence can
/// be rebuilt from its tokens, but they are not words and carry no reading. The
/// dictionary form is there when the tokenizer knows it (an inflected verb's 頷く
/// under 頷い); nil when it does not.
public struct Token: Equatable, Sendable {
    public let surface: String
    public let reading: String
    public let range: Range<String.Index>
    public let isWord: Bool
    public let dictionaryForm: String?

    public init(
        surface: String, reading: String, range: Range<String.Index>, isWord: Bool,
        dictionaryForm: String? = nil
    ) {
        self.surface = surface
        self.reading = reading
        self.range = range
        self.isWord = isWord
        self.dictionaryForm = dictionaryForm
    }
}

/// Cuts a text into tokens. Two live side by side while the choice is compared in
/// the field: the OS's analyzer and MeCab; the screen switches between them.
public protocol Tokenizer {
    func tokens(in text: String) -> [Token]
}
