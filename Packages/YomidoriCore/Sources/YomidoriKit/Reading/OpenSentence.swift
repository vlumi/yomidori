import Foundation
import YomidoriCore

/// A sentence left open at the end of a page, waiting for the next still: the
/// fragment as it stood, the word asked about and where it sits, what the card
/// would be keyed on, and the still it came from. Kept whole with the next page's
/// beginning, by plain concatenation, since Japanese has no hyphenation.
struct OpenSentence: Equatable {
    let fragment: String
    let surface: String
    let offset: Int
    let headword: String
    let reading: String
    let entryID: Int?
    let stillID: UUID?
    let source: String?
}
