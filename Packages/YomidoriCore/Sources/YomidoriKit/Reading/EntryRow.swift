import SwiftUI
import YomidoriCore

/// A dictionary entry in a list, on two lines: the headword with its first reading (the pitch
/// drawn when known) and the kept mark, then its first gloss. The first line wraps rather
/// than squeeze the word.
struct EntryRow: View {
    let entry: DictionaryEntry
    var accent: PitchAccent?
    /// The word has a card already.
    var kept = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            FlowLayout(spacing: 10) {
                Text(japanese: entry.headword)
                    .font(.title3)
                    .fixedSize()
                let reading = Kana.hiragana(entry.readings.first ?? "")
                if let accent {
                    PitchReading(reading: reading, accent: accent)
                } else {
                    Text(japanese: reading)
                        .font(.title3)
                        .foregroundStyle(Palette.nightGreen)
                        .fixedSize()
                }
                if kept {
                    Image(systemName: "rectangle.stack.fill")
                        .font(.caption)
                        .foregroundStyle(Palette.nightGreen)
                        .padding(.top, 6)
                        .accessibilityLabel(Text("Kept", bundle: .module))
                }
            }
            if let gloss = entry.senses.first?.glosses.first {
                Text(verbatim: gloss)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
