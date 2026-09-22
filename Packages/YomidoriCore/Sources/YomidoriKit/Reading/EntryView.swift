import SwiftUI
import YomidoriCore
import YomidoriDictionary

struct EntryView: View {
    let entry: DictionaryEntry
    @State private var kept = false
    @State private var details = WordDetails()

    private var reading: String {
        Kana.hiragana(entry.readings.first ?? "")
    }

    var body: some View {
        List {
            Section {
                WordTitle(
                    headword: entry.headword, reading: reading, accent: details.accent(of: reading),
                    font: .largeTitle
                ) {
                    DictionaryButton(term: entry.headword)
                        .labelStyle(.iconOnly)
                    keepButton
                }
            }
            WordSections(headword: entry.headword, details: details)
        }
        .navigationTitle(Text(verbatim: entry.headword))
        .task(id: entry.id) {
            Cards.noteLookup(of: entry, from: .search)
            details = await WordDetails.load(
                headword: entry.headword, reading: reading, entry: entry)
        }
    }

    @ViewBuilder private var keepButton: some View {
        if kept || Cards.store?.card(headword: entry.headword, reading: reading) != nil {
            Image(systemName: "checkmark")
                .foregroundStyle(.secondary)
                .accessibilityLabel(Text("Kept", bundle: .module))
        } else if Cards.store != nil {
            Button(action: keep) {
                Label {
                    Text("Keep", bundle: .module)
                } icon: {
                    Image(systemName: "plus.rectangle.on.rectangle")
                }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private func keep() {
        let sighting = Sighting(
            sentence: "", surface: entry.headword, offset: 0, stillIDs: [], source: nil,
            date: Date())
        if (try? Cards.store?.keep(
            sighting, headword: entry.headword, reading: reading, entryID: entry.id,
            collection: Cards.currentCollectionID())) != nil
        {
            kept = true
        }
    }
}
