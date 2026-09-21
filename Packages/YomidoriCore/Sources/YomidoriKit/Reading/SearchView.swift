import SwiftUI
import YomidoriCore
import YomidoriDictionary

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
