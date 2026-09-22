import SwiftUI
import YomidoriCore
import YomidoriDictionary

struct SearchView: View {
    @State private var query = ""
    @State private var results: [DictionaryEntry] = []
    @State private var kept: Set<String> = []
    /// Bumped when the history is cleared, so its view reloads.
    @State private var historyGeneration = 0

    var body: some View {
        ScrollViewReader { proxy in
            list.scrollsToTopOnReselect(of: .search, with: proxy)
        }
    }

    private var list: some View {
        List {
            if SearchQuery.kind(of: query) == .empty {
                LookupHistoryView(generation: historyGeneration)
                    .id(TabTop.id)
            } else if results.isEmpty {
                Text("No matches.", bundle: .module)
                    .foregroundStyle(.secondary)
            }
            ForEach(results) { entry in
                NavigationLink(value: entry) {
                    EntryRow(
                        entry: entry,
                        kept: kept.contains(
                            WordKey.of(
                                headword: entry.headword,
                                reading: Kana.hiragana(entry.readings.first ?? ""))))
                }
            }
        }
        .searchable(text: $query, prompt: Text("Kana, kanji, or English", bundle: .module))
        .navigationTitle(Text("Search", bundle: .module))
        .toolbar {
            if SearchQuery.kind(of: query) == .empty, Cards.lookups?.lookups().isEmpty == false {
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .destructive) {
                        try? Cards.lookups?.clear()
                        historyGeneration += 1
                    } label: {
                        Text("Clear", bundle: .module)
                    }
                }
            }
        }
        .task(id: query) {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            results = JMdict.bundled?.search(query, limit: 50) ?? []
            kept = Cards.keptWords()
        }
    }
}
