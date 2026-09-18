import Foundation

/// A word as the tokenizer cut it, with its reading. The reading is hiragana, the
/// form a reader expects; punctuation and spaces are tokens too, so a sentence can
/// be rebuilt from its tokens, but they are not words and carry no reading.
public struct Token: Equatable, Sendable {
    public let surface: String
    public let reading: String
    public let range: Range<String.Index>
    public let isWord: Bool

    public init(surface: String, reading: String, range: Range<String.Index>, isWord: Bool) {
        self.surface = surface
        self.reading = reading
        self.range = range
        self.isWord = isWord
    }
}
