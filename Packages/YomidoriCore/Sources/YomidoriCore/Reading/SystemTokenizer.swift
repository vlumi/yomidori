import Foundation

/// Words and readings from `CFStringTokenizer`'s Latin transcription, which ICU turns back
/// into hiragana losslessly (づ and ず, おう and おお stay apart).
public struct SystemTokenizer: Tokenizer {
    public init() {}

    public func tokens(in text: String) -> [Token] {
        let cfText = text as CFString
        let tokenizer = CFStringTokenizerCreate(
            nil, cfText, CFRangeMake(0, CFStringGetLength(cfText)),
            kCFStringTokenizerUnitWordBoundary, Locale(identifier: "ja") as CFLocale)
        var tokens: [Token] = []
        // Where the last token ended, in UTF-16.
        var covered = 0
        while CFStringTokenizerAdvanceToNextToken(tokenizer).rawValue != 0 {
            let cfRange = CFStringTokenizerGetCurrentTokenRange(tokenizer)
            // The tokenizer may stop inside a character (気 of 気 + U+FE0F, は + ZWJ): grown
            // to whole characters, and a token that is then already covered is dropped.
            let whole = (text as NSString).rangeOfComposedCharacterSequences(
                for: NSRange(location: cfRange.location, length: cfRange.length))
            let lower = max(whole.location, covered)
            let upper = whole.location + whole.length
            guard upper > lower else { continue }
            covered = upper
            let start = String.Index(utf16Offset: lower, in: text)
            let end = String.Index(utf16Offset: upper, in: text)
            let surface = String(text[start..<end])
            let isWord = surface.unicodeScalars.contains { CharacterSet.letters.contains($0) }
            let latin =
                CFStringTokenizerCopyCurrentTokenAttribute(
                    tokenizer, kCFStringTokenizerAttributeLatinTranscription) as? String
            let reading =
                isWord
                ? latin?.applyingTransform(.latinToHiragana, reverse: false) ?? surface
                : surface
            tokens.append(
                Token(surface: surface, reading: reading, range: start..<end, isWord: isWord))
        }
        return tokens
    }
}
