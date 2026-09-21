import Foundation

/// Punctuation and spaces are tokens too, so a sentence can be rebuilt from its tokens,
/// but they are not words and carry no reading.
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

public protocol Tokenizer {
    func tokens(in text: String) -> [Token]
}
