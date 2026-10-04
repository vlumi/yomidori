import SwiftUI
import YomidoriCore
import YomidoriDictionary

struct EntryView: View {
    let entry: DictionaryEntry
    @State private var kept = false
    @State private var details = WordDetails()
    @State private var openedCard: Card?

    var body: some View {
        List {
            Section {
                WordTitle(
                    headword: entry.headword, reading: entry.hiraganaReading,
                    accent: details.accent(of: entry.hiraganaReading),
                    estimate: details.estimate, font: .largeTitle
                ) {
                    DictionaryButton(term: entry.headword)
                        .labelStyle(.iconOnly)
                        .help(Text("Dictionary", bundle: .module))
                    keepButton
                }
            }
            WordSections(headword: entry.headword, details: details)
        }
        .navigationTitle(Text(verbatim: entry.headword))
        .sheet(item: $openedCard) { card in
            CardSheet(card: card)
        }
        .task(id: entry.id) {
            Cards.noteLookup(of: entry, from: .search)
            details = await WordDetails.load(
                headword: entry.headword, reading: entry.hiraganaReading, entry: entry)
        }
    }

    private var keepButton: some View {
        KeepButton(
            kept: kept
                || Cards.store?.card(headword: entry.headword, reading: entry.hiraganaReading)
                    != nil,
            canKeep: Cards.store != nil, keep: keep,
            open: {
                openedCard = Cards.store?.card(
                    headword: entry.headword, reading: entry.hiraganaReading)
            })
    }

    private func keep() {
        let sighting = Sighting(
            sentence: "", surface: entry.headword, offset: 0, source: nil,
            date: Date())
        let card = Cards.write {
            try Cards.store?.keep(
                sighting, headword: entry.headword, reading: entry.hiraganaReading,
                entryID: entry.id, collection: Cards.currentCollectionID())
        }
        if card != nil { kept = true }
    }
}
