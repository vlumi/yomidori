import SwiftUI
import YomidoriCore
import YomidoriDictionary

/// One card: the word with its reading and pitch, and every sentence it was met in,
/// the word marked in each, with the still it was read from.
struct CardView: View {
    @State var card: Card

    var body: some View {
        List {
            Section {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(verbatim: card.headword)
                        .font(.largeTitle)
                    if let accent = JMdict.bundled?.pitchAccents(
                        for: card.headword, reading: card.reading
                    ).first {
                        PitchReading(reading: card.reading, accent: accent)
                    } else {
                        Text(verbatim: card.reading)
                            .font(.title3)
                            .foregroundStyle(Palette.nightGreen)
                    }
                    Spacer()
                    DictionaryButton(term: card.headword)
                }
                .textSelection(.enabled)
            }
            Section {
                Toggle(isOn: $card.asksMeaning) {
                    Text("Ask the meaning too", bundle: .module)
                }
                .tint(Palette.nightGreen)
            } footer: {
                Text(
                    // swiftlint:disable:next line_length
                    "The reading is always asked. With this on, the word is also asked for its meaning, on its own schedule.",
                    bundle: .module)
            }
            ForEach(card.sightings.sorted { $0.date > $1.date }) { sighting in
                Section {
                    if sighting.sentence.isEmpty {
                        Text("Kept from a search; no sentence yet.", bundle: .module)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        MarkedSentence(sighting: sighting)
                    }
                    let images = [sighting.cropID].compactMap { $0 } + sighting.stillIDs
                    ForEach(images, id: \.self) { id in
                        if let image = StillArchive.load(id) {
                            Image(decorative: image, scale: 1)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                } footer: {
                    Text(
                        verbatim: [
                            sighting.source,
                            sighting.date.formatted(date: .abbreviated, time: .omitted),
                        ].compactMap { $0 }.joined(separator: " · "))
                }
            }
        }
        .navigationTitle(Text(verbatim: card.headword))
        .task(id: card.asksMeaning) { try? Cards.store?.update(card) }
    }

}
