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
        while CFStringTokenizerAdvanceToNextToken(tokenizer).rawValue != 0 {
            let cfRange = CFStringTokenizerGetCurrentTokenRange(tokenizer)
            let start = String.Index(utf16Offset: cfRange.location, in: text)
            let end = String.Index(utf16Offset: cfRange.location + cfRange.length, in: text)
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
