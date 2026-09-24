import YomidoriCore
import YomidoriDictionary

/// Reads a page into its chunks off the main thread, one page at a time, so the tokenizer is
/// never used from two places at once.
actor PageReader {
    static let shared = PageReader()

    func read(_ text: String, with choice: TokenizerChoice) -> PageReading {
        let tokenizer = choice.tokenizer
        return PageReading(
            text: text, tokens: { tokenizer?.tokens(in: $0) ?? [] }, dictionary: JMdict.bundled)
    }
}
