import SwiftUI
import YomidoriCore

struct WordTitle<Trailing: View>: View {
    let headword: String
    let reading: String
    var accent: PitchAccent?
    /// The pitch as worked out, shown where there is no accent and it spells this reading.
    var estimate: [PitchPhrase] = []
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
        Text(japanese: headword)
            .font(font)
            .fixedSize()
    }

    /// The estimate, if it is of this very reading: a word met in another form has none.
    private var shownEstimate: [PitchPhrase] {
        guard accent == nil,
            Kana.hiragana(estimate.map(\.reading).joined()) == Kana.hiragana(reading)
        else { return [] }
        return estimate
    }

    private var readingView: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            if let accent {
                PitchReading(reading: reading, accent: accent)
            } else if !shownEstimate.isEmpty {
                EstimatedPitch(phrases: shownEstimate)
            } else {
                Text(japanese: reading)
                    .font(.title3)
                    .foregroundStyle(Palette.nightGreen)
            }
            if let dictionaryForm {
                Text(japanese: dictionaryForm)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .fixedSize()
    }
}
