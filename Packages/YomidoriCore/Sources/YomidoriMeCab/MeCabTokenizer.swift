import Foundation
import IPADic
import Mecab_Swift
import YomidoriCore

/// IPADic knows dictionary forms and parts of speech; an unknown word comes back without
/// a reading.
public final class MeCabTokenizer: YomidoriCore.Tokenizer {
    /// Loading the dictionary takes tens of megabytes; once per app.
    public static let shared: MeCabTokenizer? = try? MeCabTokenizer()

    private let mecab: Mecab_Swift.Tokenizer

    public init() throws {
        mecab = try Mecab_Swift.Tokenizer(dictionary: IPADic())
    }

    public func tokens(in text: String) -> [Token] {
        mecab.tokenize(text: text, transliteration: .hiragana).map { annotation in
            let surface = annotation.base
            let isWord = surface.unicodeScalars.contains { CharacterSet.letters.contains($0) }
            let reading = annotation.reading.isEmpty ? surface : annotation.reading
            let form = annotation.dictionaryForm
            return Token(
                surface: surface, reading: isWord ? reading : surface, range: annotation.range,
                isWord: isWord,
                dictionaryForm: form.isEmpty || form == "*" || form == surface ? nil : form)
        }
    }
}
