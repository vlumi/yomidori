import YomidoriCore
import YomidoriMeCab

/// Which analyzer cuts the page: the system's or MeCab, switched under the page while the
/// two are compared, and remembered.
enum TokenizerChoice: String, CaseIterable {
    case system
    case mecab

    static let key = "tokenizer"

    var tokenizer: (any Tokenizer)? {
        switch self {
        case .system: return SystemTokenizer()
        case .mecab: return MeCabTokenizer.shared
        }
    }
}
