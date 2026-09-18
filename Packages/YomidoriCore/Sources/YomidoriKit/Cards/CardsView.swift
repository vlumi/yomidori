import SwiftUI
import YomidoriCore
import YomidoriDictionary

/// The cards kept so far, newest first: the word, its reading, how often it was
/// met. Swipe to remove. Tap for the card itself.
struct CardsView: View {
    @State private var cards: [Card] = []
    @State private var dueCount = 0

    var body: some View {
        List {
            if cards.isEmpty {
                Text("No cards yet. Tap a word under a page and keep it.", bundle: .module)
                    .foregroundStyle(.secondary)
            }
            ForEach(cards) { card in
                NavigationLink(value: card) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(verbatim: card.headword)
                            .font(.title3)
                        Text(verbatim: card.reading)
                            .foregroundStyle(Palette.nightGreen)
                        Spacer()
                        Text(verbatim: "\(card.sightings.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { offsets in
                for index in offsets {
                    try? Cards.store?.remove(cards[index])
                }
                reload()
            }
        }
        .navigationTitle(Text("Cards", bundle: .module))
        .toolbar {
            if dueCount > 0 {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(value: Screen.review) {
                        Label {
                            Text("Review \(dueCount)", bundle: .module)
                        } icon: {
                            Image(systemName: "checkmark.rectangle.stack")
                        }
                    }
                }
            }
        }
        .onAppear(perform: reload)
    }

    private func reload() {
        cards = (Cards.store?.cards() ?? []).sorted { $0.created > $1.created }
        dueCount = Cards.store?.dueItems(at: Date()).count ?? 0
    }
}

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
                        Text(marked(sighting))
                            .font(.title3)
                            .textSelection(.enabled)
                    }
                    ForEach(sighting.stillIDs, id: \.self) { id in
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

    /// The sentence with the word as it stood on the page in night green.
    private func marked(_ sighting: Sighting) -> AttributedString {
        var text = AttributedString(sighting.sentence)
        let characters = Array(sighting.sentence)
        guard sighting.offset >= 0, sighting.offset + sighting.surface.count <= characters.count
        else {
            return text
        }
        let start = text.index(text.startIndex, offsetByCharacters: sighting.offset)
        let end = text.index(start, offsetByCharacters: sighting.surface.count)
        text[start..<end].foregroundColor = Palette.nightGreen
        text[start..<end].font = .title3.bold()
        return text
    }
}
