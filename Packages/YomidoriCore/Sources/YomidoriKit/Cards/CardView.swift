import SwiftUI
import YomidoriCore
import YomidoriDictionary

struct CardView: View {
    @State var card: Card
    @State private var details = WordDetails()
    @State private var editing: Sighting?

    var body: some View {
        List {
            Section {
                WordTitle(
                    headword: card.headword, reading: card.reading,
                    accent: details.accent(of: card.reading), font: .largeTitle
                ) {
                    DictionaryButton(term: card.headword)
                        .labelStyle(.iconOnly)
                }
            }
            WordSections(headword: card.headword, details: details)
            CardCollections(card: $card) { try? Cards.store?.update(card) }
            CardActions(card: $card) { try? Cards.store?.update(card) }
            AcceptedMeanings(card: $card) { try? Cards.store?.update(card) }
            CardFacts(card: card)
            ForEach(card.sightings.sorted { $0.date > $1.date }) { sighting in
                SightingSection(sighting: sighting) {
                    editing = sighting
                }
            }
        }
        .navigationTitle(Text(verbatim: card.headword))
        .sheet(item: $editing) { sighting in
            SentenceEditor(sighting: sighting, save: replace)
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
        try? Cards.store?.update(card)
    }
}
