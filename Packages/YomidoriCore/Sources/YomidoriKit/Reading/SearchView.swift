import SwiftUI
import YomidoriCore
import YomidoriDictionary

struct SearchView: View {
    @State private var query = ""
    @State private var results: [DictionaryEntry] = []
    @State private var kept: Set<String> = []
    /// Bumped when the history is cleared, so its view reloads.
    @State private var historyGeneration = 0
    @State private var accents: [Int: PitchAccent] = [:]
    @FocusState private var searching: Bool
    @State private var buildingKanji = false
    @EnvironmentObject private var taps: TabTaps

    var body: some View {
        ScrollViewReader { proxy in
            list.scrollsToTopOnReselect(of: .search, with: proxy)
        }
    }

    private var list: some View {
        List {
            // In the list, not the navigation bar, which hides while the field is focused.
            Button {
                buildingKanji = true
            } label: {
                partsLabel
            }
            .tint(Palette.nightGreen)
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
                        entry: entry, accent: accents[entry.id],
                        kept: kept.contains(
                            WordKey.of(
                                headword: entry.headword,
                                reading: Kana.hiragana(entry.readings.first ?? ""))))
                }
            }
        }
        .searchable(text: $query, prompt: Text("Kana, kanji, or English", bundle: .module))
        .searchFocused($searching)
        // Switched to, the tab is for typing: the field takes the keyboard at once.
        .onChange(of: taps.shown, initial: true) { _, shown in
            if shown == .search { searching = true }
        }
        .navigationTitle(Text("Search", bundle: .module))
        .toolbar {
            ToolbarItem(placement: .keyboard) {
                Button {
                    buildingKanji = true
                } label: {
                    partsLabel
                }
            }
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
        .sheet(isPresented: $buildingKanji, onDismiss: { searching = true }) {
            KanjiByPartsView(query: $query)
        }
        .task(id: query) {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            results = JMdict.bundled?.search(query, limit: 50) ?? []
            accents = Dictionary(
                results.compactMap { entry in
                    JMdict.bundled?.pitchAccent(of: entry).map { (entry.id, $0) }
                }, uniquingKeysWith: { first, _ in first })
            kept = Cards.keptWords()
        }
    }

    private var partsLabel: some View {
        Label {
            Text("Kanji by parts", bundle: .module)
        } icon: {
            Image(systemName: "square.grid.3x3.square")
        }
    }
}
