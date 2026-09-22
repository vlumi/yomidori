import SwiftUI
import YomidoriCore

struct WordTitle<Trailing: View>: View {
    let headword: String
    let reading: String
    var accent: PitchAccent?
    var dictionaryForm: String?
    var font: Font = .title
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                word
                readingView
                Spacer()
                trailing()
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    word
                    Spacer()
                    trailing()
                }
                readingView
            }
        }
        .textSelection(.enabled)
    }

    private var word: some View {
        Text(verbatim: headword)
            .font(font)
            .fixedSize()
    }

    private var readingView: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            if let accent {
                PitchReading(reading: reading, accent: accent)
            } else {
                Text(verbatim: reading)
                    .font(.title3)
                    .foregroundStyle(Palette.nightGreen)
            }
            if let dictionaryForm {
                Text(verbatim: dictionaryForm)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .fixedSize()
    }
}
