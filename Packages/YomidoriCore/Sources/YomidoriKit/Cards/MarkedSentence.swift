import SwiftUI
import YomidoriCore

struct MarkedSentence: View {
    let sighting: Sighting
    var font: Font = .title3

    var body: some View {
        Text(marked)
            .font(font)
            .textSelection(.enabled)
    }

    private var marked: AttributedString {
        var text = AttributedString(sighting.sentence)
        guard let range = sighting.surfaceRange,
            let start = AttributedString.Index(range.lowerBound, within: text),
            let end = AttributedString.Index(range.upperBound, within: text)
        else { return text }
        text[start..<end].foregroundColor = Palette.nightGreen
        text[start..<end].font = font.bold()
        return text
    }
}
