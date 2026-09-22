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
            CardActions(card: $card) { try? Cards.store?.update(card) }
            AcceptedMeanings(card: $card) { try? Cards.store?.update(card) }
            CardFacts(card: card)
            ForEach(card.sightings.sorted { $0.date > $1.date }) { sighting in
                SightingSection(sighting: sighting) {
                    editing = sighting
                } removeImages: {
                    removeImages(of: sighting)
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
    }

    private func replace(_ sighting: Sighting) {
        card.replace(sighting)
        try? Cards.store?.update(card)
    }

    private func removeImages(of sighting: Sighting) {
        replace(sighting.withoutImages())
        let ids = [sighting.cropID].compactMap { $0 } + sighting.stillIDs
        StillArchive.remove(ids, keptBy: Cards.store?.cards() ?? [])
    }
}
