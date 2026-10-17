import SwiftUI
import YomidoriCore

struct MarkedSentence: View {
    let sighting: Sighting
    /// The card's headword, which decides what is marked: the whole verb, or the noun
    /// without its する.
    let headword: String
    var font: Font = .title3

    var body: some View {
        Text(marked)
            .font(font)
            .textSelection(.enabled)
    }

    private var marked: AttributedString {
        var text = AttributedString(sighting.sentence)
        text.languageIdentifier = "ja"
        guard let range = sighting.markedRange(headword: headword, tokenizer: SystemTokenizer()),
            let start = AttributedString.Index(range.lowerBound, within: text),
            let end = AttributedString.Index(range.upperBound, within: text)
        else { return text }
        text[start..<end].foregroundColor = Palette.nightGreen
        text[start..<end].font = font.bold()
        return text
    }
}
