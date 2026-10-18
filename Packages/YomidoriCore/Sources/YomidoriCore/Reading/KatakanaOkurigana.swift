import Foundation

/// Text in the old official style writes its endings and particles in katakana (但シ,
/// 従ハザル者ハ処刑スル): the tokenizer cuts those apart and the dictionary knows none of
/// them. Such a line is read with that katakana as hiragana, as the same text in hiragana
/// is read; the loanwords in it stay as written.
public enum KatakanaOkurigana {
    /// The line with its okurigana katakana as hiragana; nil where the line is not in that
    /// style or nothing in it changes. `isWord` says whether the dictionary lists a word
    /// spelled exactly so. Kana map one to one, so every offset into the result is the
    /// same offset into the line.
    public static func folded(_ line: String, isWord: (String) -> Bool) -> String? {
        let scalars = Array(line.unicodeScalars)
        // The style has no hiragana at all, and kanji with katakana after them.
        guard !scalars.contains(where: isHiragana), scalars.contains(where: isKanji),
            scalars.contains(where: isKatakana)
        else { return nil }
        var out = String.UnicodeScalarView()
        var index = 0
        var changed = false
        while index < scalars.count {
            guard isKatakana(scalars[index]) else {
                out.append(scalars[index])
                index += 1
                continue
            }
            if let kept = loanword(in: scalars, at: index, isWord: isWord) {
                out.append(contentsOf: scalars[index..<kept])
                index = kept
                continue
            }
            let folded = Kana.hiragana(String(scalars[index]))
            changed = changed || folded.unicodeScalars.first != scalars[index]
            out.append(contentsOf: folded.unicodeScalars)
            index += 1
        }
        return changed ? String(out) : nil
    }

    /// Tokens of the line, read through `folded` where the line is in the style: each
    /// token's surface and reading are the folded text, for the dictionary, its range
    /// indexes the line as given, and `written` keeps what the page has.
    public static func tokens(
        in line: String, tokenizer: (String) -> [Token], isWord: (String) -> Bool
    ) -> [Token] {
        guard let folded = folded(line, isWord: isWord) else { return tokenizer(line) }
        return tokenizer(folded).map { token in
            let lower = token.range.lowerBound.utf16Offset(in: folded)
            let upper = token.range.upperBound.utf16Offset(in: folded)
            let start = String.Index(utf16Offset: lower, in: line)
            let end = String.Index(utf16Offset: upper, in: line)
            let written = String(line[start..<end])
            return Token(
                surface: token.surface, reading: token.reading, range: start..<end,
                isWord: token.isWord, dictionaryForm: token.dictionaryForm,
                written: written == token.surface ? nil : written)
        }
    }

    /// The end of the longest loanword starting at `start`: a run the dictionary lists in
    /// katakana that also looks borrowed, so the single kana and the short words it lists
    /// (シ, ハ, ザル, タイ) are not taken for one.
    private static func loanword(
        in scalars: [Unicode.Scalar], at start: Int, isWord: (String) -> Bool
    ) -> Int? {
        var end = start
        while end < scalars.count, isKatakana(scalars[end]) { end += 1 }
        var stop = end
        while stop > start + 1 {
            let run = scalars[start..<stop]
            let text = String(String.UnicodeScalarView(run))
            if looksBorrowed(run), isWord(text) { return stop }
            stop -= 1
        }
        return nil
    }

    private static func looksBorrowed(_ run: ArraySlice<Unicode.Scalar>) -> Bool {
        run.count >= 3 || run.contains { borrowedMarks.contains($0.value) }
    }

    /// ー, the small vowels, ヴ and the パ row: what the old style's endings never have.
    private static let borrowedMarks: Set<UInt32> = [
        0x30FC, 0x30A1, 0x30A3, 0x30A5, 0x30A7, 0x30A9, 0x30F4, 0x30D1, 0x30D4, 0x30D7,
        0x30DA, 0x30DD,
    ]

    private static func isHiragana(_ scalar: Unicode.Scalar) -> Bool {
        (0x3041...0x309F).contains(scalar.value)
    }

    private static func isKatakana(_ scalar: Unicode.Scalar) -> Bool {
        (0x30A1...0x30FA).contains(scalar.value) || scalar.value == 0x30FC
    }

    private static func isKanji(_ scalar: Unicode.Scalar) -> Bool {
        (0x4E00...0x9FFF).contains(scalar.value) || (0x3400...0x4DBF).contains(scalar.value)
            || scalar.value == 0x3005
    }
}
