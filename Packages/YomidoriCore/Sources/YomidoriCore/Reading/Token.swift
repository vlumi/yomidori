import Foundation

/// Punctuation and spaces are tokens too, so a sentence can be rebuilt from its tokens,
/// but they are not words and carry no reading.
public struct Token: Equatable, Sendable {
    public let surface: String
    public let reading: String
    public let range: Range<String.Index>
    public let isWord: Bool
    public let dictionaryForm: String?
    /// The page's own spelling where the surface was read from another (ヨリ read as
    /// より); nil where they are the same.
    public let written: String?

    public init(
        surface: String, reading: String, range: Range<String.Index>, isWord: Bool,
        dictionaryForm: String? = nil, written: String? = nil
    ) {
        self.surface = surface
        self.reading = reading
        self.range = range
        self.isWord = isWord
        self.dictionaryForm = dictionaryForm
        self.written = written
    }
}

public protocol Tokenizer {
    func tokens(in text: String) -> [Token]
}
