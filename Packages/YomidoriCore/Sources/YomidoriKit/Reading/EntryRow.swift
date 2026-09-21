import SwiftUI
import YomidoriCore

/// A dictionary entry in a list: the headword, its first reading with the pitch when given,
/// and its first gloss.
struct EntryRow: View {
    let entry: DictionaryEntry
    var accent: PitchAccent?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(verbatim: entry.headword)
                .font(.title3)
            let reading = Kana.hiragana(entry.readings.first ?? "")
            if let accent {
                PitchReading(reading: reading, accent: accent)
            } else {
                Text(verbatim: reading)
                    .foregroundStyle(Palette.nightGreen)
            }
            Spacer()
            Text(verbatim: entry.senses.first?.glosses.first ?? "")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
