import SwiftUI
import YomidoriCore
import YomidoriDictionary

/// One dictionary entry on its own: the word with its pitch, its senses, the system
/// dictionary, and Keep, which makes a card with no sentence yet; the sentences
/// come when the word is met on a page.
struct EntryView: View {
    let entry: DictionaryEntry
    @State private var kept = false

    private var reading: String {
        Kana.hiragana(entry.readings.first ?? "")
    }

    var body: some View {
        List {
            Section {
                WordTitle(
                    headword: entry.headword, reading: reading,
                    accent: JMdict.bundled?.pitchAccents(for: entry.headword, reading: reading)
                        .first,
                    font: .largeTitle
                ) {
                    DictionaryButton(term: entry.headword)
                }
                if entry.readings.count > 1 || entry.kanji.count > 1 {
                    Text(
                        verbatim: (entry.kanji + entry.readings.map(Kana.hiragana)).joined(
                            separator: "、")
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
            }
            Section {
                ForEach(entry.senses.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: entry.senses[index].partsOfSpeech.joined(separator: ", "))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(
                            verbatim:
                                "\(index + 1). \(entry.senses[index].glosses.joined(separator: "; "))"
                        )
                    }
                }
            }
            Section {
                if kept || Cards.store?.card(headword: entry.headword, reading: reading) != nil {
                    Label {
                        Text("Kept", bundle: .module)
                    } icon: {
                        Image(systemName: "checkmark")
                    }
                    .foregroundStyle(.secondary)
                } else if Cards.store != nil {
                    Button {
                        keep()
                    } label: {
                        Label {
                            Text("Keep", bundle: .module)
                        } icon: {
                            Image(systemName: "plus.rectangle.on.rectangle")
                        }
                    }
                }
            }
        }
        .navigationTitle(Text(verbatim: entry.headword))
    }

    private func keep() {
        let sighting = Sighting(
            sentence: "", surface: entry.headword, offset: 0, stillIDs: [], source: nil,
            date: Date())
        if (try? Cards.store?.keep(
            sighting, headword: entry.headword, reading: reading, entryID: entry.id)) != nil
        {
            kept = true
        }
    }
}
