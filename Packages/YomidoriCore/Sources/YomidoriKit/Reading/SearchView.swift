import SwiftUI
import YomidoriCore
import YomidoriDictionary

/// Words met off the page: type kana or kanji for headwords and readings that
/// start with it, or English for the glosses. No mode switch; the query says which.
/// A result opens the word as a tapped word would, and can be kept as a card.
struct SearchView: View {
    @State private var query = ""
    @State private var results: [DictionaryEntry] = []

    var body: some View {
        List {
            if results.isEmpty, SearchQuery.kind(of: query) != .empty {
                Text("No matches.", bundle: .module)
                    .foregroundStyle(.secondary)
            }
            ForEach(results) { entry in
                NavigationLink(value: entry) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(verbatim: entry.headword)
                            .font(.title3)
                        Text(verbatim: Kana.hiragana(entry.readings.first ?? ""))
                            .foregroundStyle(Palette.nightGreen)
                        Spacer()
                        Text(verbatim: entry.senses.first?.glosses.first ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .searchable(text: $query, prompt: Text("Kana, kanji, or English", bundle: .module))
        .navigationTitle(Text("Search", bundle: .module))
        .navigationDestination(for: DictionaryEntry.self) { entry in
            EntryView(entry: entry)
        }
        .task(id: query) {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            results = JMdict.bundled?.search(query, limit: 50) ?? []
        }
    }
}

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
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(verbatim: entry.headword)
                        .font(.largeTitle)
                    if let accent = JMdict.bundled?.pitchAccents(
                        for: entry.headword, reading: reading
                    ).first {
                        PitchReading(reading: reading, accent: accent)
                    } else {
                        Text(verbatim: reading)
                            .font(.title3)
                            .foregroundStyle(Palette.nightGreen)
                    }
                    Spacer()
                    DictionaryButton(term: entry.headword)
                }
                .textSelection(.enabled)
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
