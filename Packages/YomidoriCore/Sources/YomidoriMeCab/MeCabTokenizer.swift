import Foundation
import IPADic
import Mecab_Swift
import YomidoriCore

/// MeCab with IPADic, the alternative to the OS's analyzer, kept so the two can be
/// compared on real pages. IPADic knows dictionary forms and parts of speech and is
/// old (2007); an unknown word comes back without a reading, and keeps its surface.
public final class MeCabTokenizer: YomidoriCore.Tokenizer {
    /// Loading the dictionary takes a moment and tens of megabytes; once per app.
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
