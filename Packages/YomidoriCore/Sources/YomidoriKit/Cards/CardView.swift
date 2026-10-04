import SwiftUI
import YomidoriCore
import YomidoriDictionary

struct CardView: View {
    @State var card: Card
    @State private var details = WordDetails()
    @State private var editing: Sighting?
    /// A sentence met elsewhere, typed or pasted onto the card.
    @State private var adding: Sighting?

    var body: some View {
        List {
            Section {
                WordTitle(
                    headword: card.headword, reading: card.reading,
                    accent: details.accent(of: card.reading), estimate: details.estimate,
                    font: .largeTitle
                ) {
                    DictionaryButton(term: card.headword)
                        .labelStyle(.iconOnly)
                        .help(Text("Dictionary", bundle: .module))
                }
            }
            WordSections(headword: card.headword, details: details)
            CardCollections(card: $card) { Cards.write { try Cards.store?.update(card) } }
            CardActions(card: $card) { Cards.write { try Cards.store?.update(card) } }
            AcceptedMeanings(card: $card, glosses: details.entry?.senses.flatMap(\.glosses) ?? []) {
                Cards.write { try Cards.store?.update(card) }
            }
            CardFacts(card: card)
            ForEach(card.sightings.sorted { $0.date > $1.date }) { sighting in
                SightingSection(sighting: sighting) {
                    editing = sighting
                }
            }
            Section {
                Button {
                    adding = Sighting(
                        sentence: "", surface: card.headword, offset: 0, source: nil, date: Date())
                } label: {
                    Label {
                        Text("Add a sentence", bundle: .module)
                    } icon: {
                        Image(systemName: "text.badge.plus")
                    }
                }
            } footer: {
                Text("Met the word somewhere else? Type or paste the sentence.", bundle: .module)
            }
        }
        .navigationTitle(Text(verbatim: card.headword))
        .sheet(item: $editing) { sighting in
            SentenceEditor(sighting: sighting, save: replace)
                .sheetSize(width: 520, height: 360)
        }
        .sheet(item: $adding) { sighting in
            SentenceEditor(sighting: sighting) { added in
                guard !added.sentence.isEmpty else { return }
                card.add(added)
                Cards.write { try Cards.store?.update(card) }
            }
        }
        .task(id: card.id) {
            details = await WordDetails.load(headword: card.headword, reading: card.reading)
        }
        // A review, or another device, may change the card while it is open; the next edit
        // then writes over the stored card, not the one this screen started with.
        .onReceive(Cards.changes(of: [.card])) { _ in
            if let stored = Cards.store?.card(id: card.id), stored != card { card = stored }
        }
    }

    private func replace(_ sighting: Sighting) {
        card.replace(sighting)
        Cards.write { try Cards.store?.update(card) }
    }
}
