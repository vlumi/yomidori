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
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(verbatim: headword)
                .font(font)
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
            Spacer()
            trailing()
        }
        .textSelection(.enabled)
    }
}
