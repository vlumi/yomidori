import YomidoriCore
import YomidoriDictionary

/// Reads a page into its chunks off the main thread, one page at a time, so the tokenizer is
/// never used from two places at once.
actor PageReader {
    static let shared = PageReader()

    func read(_ text: String, with choice: TokenizerChoice) -> PageReading {
        let tokenizer = choice.tokenizer
        let dictionary = JMdict.bundled
        return PageReading(
            text: text,
            tokens: { line in
                KatakanaOkurigana.tokens(
                    in: line, tokenizer: { tokenizer?.tokens(in: $0) ?? [] },
                    isWord: { !(dictionary?.entries(matching: $0).isEmpty ?? true) })
            }, dictionary: dictionary)
    }
}
