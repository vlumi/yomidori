import SwiftUI
import YomidoriCore

struct KanjiRow: View {
    let kanji: KanjiEntry

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(japanese: kanji.literal)
                .font(.title)
            VStack(alignment: .leading, spacing: 2) {
                Text(japanese: (kanji.onReadings + kanji.kunReadings).joined(separator: "、"))
                    .font(.callout)
                    .foregroundStyle(Palette.nightGreen)
                    .lineLimit(1)
                Text(verbatim: kanji.meanings.prefix(3).joined(separator: "; "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
