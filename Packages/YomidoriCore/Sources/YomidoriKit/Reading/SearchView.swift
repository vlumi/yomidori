import SwiftUI
import YomidoriCore
import YomidoriDictionary

struct SearchView: View {
    @State private var query = DemoMode.search ?? ""
    /// The pitch worked out for the results the dictionary has no accent for.
    @State private var estimates: [Int: [PitchPhrase]] = [:]
    @State private var results: [DictionaryEntry] = []
    @State private var kept: Set<String> = []
    /// Bumped when the history is cleared, so its view reloads.
    @State private var historyGeneration = 0
    @State private var accents: [Int: PitchAccent] = [:]
    @FocusState private var searching: Bool
    @State private var buildingKanji = false
    /// The field's cursor or selection, and where it stood when the parts sheet opened.
    @State private var selection: TextSelection?
    @State private var selectionAtParts: TextSelection?
    @State private var fieldButton: SearchFieldButton?
    @EnvironmentObject private var taps: TabTaps

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
                        entry: entry, accent: accents[entry.id],
                        estimate: estimates[entry.id] ?? [],
                        kept: kept.contains(
                            WordKey.of(
                                headword: entry.headword,
                                reading: Kana.hiragana(entry.readings.first ?? ""))))
                }
            }
        }
        .searchable(text: $query, prompt: Text("Kana, kanji, or English", bundle: .module))
        .searchFocused($searching)
        .searchSelection($selection)
        // The parts sheet opens from a button at the end of the search box, put there once
        // the field has the keyboard.
        .task(id: searching) {
            if searching { await partsButton().install() }
        }
        // Switched to, the tab is for typing: the field takes the keyboard at once.
        .onChange(of: taps.shown, initial: true) { _, shown in
            if shown == .search { searching = true }
        }
        .navigationTitle(Text("Search", bundle: .module))
        .toolbar {
            #if os(macOS)
            // The search field takes no accessory here: the parts open from the toolbar.
            ToolbarItem(placement: .primaryAction) {
                Button {
                    selectionAtParts = selection
                    buildingKanji = true
                } label: {
                    Label {
                        Text("Kanji by parts", bundle: .module)
                    } icon: {
                        Image(systemName: "square.grid.3x3.square")
                    }
                }
            }
            #endif
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
            KanjiByPartsView(pick: insert)
        }
        .task(id: query) {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            // Off the main thread: a short English prefix matches thousands of glosses.
            let query = query
            let found = await Task.detached(priority: .userInitiated) {
                var found = Found(results: JMdict.bundled?.search(query, limit: 50) ?? [])
                for entry in found.results {
                    if let accent = JMdict.bundled?.pitchAccent(of: entry) {
                        found.accents[entry.id] = accent
                    } else if let estimate = JMdict.bundled?.estimatedPitch(of: entry),
                        !estimate.isEmpty
                    {
                        found.estimates[entry.id] = estimate
                    }
                }
                return found
            }.value
            guard !Task.isCancelled else { return }
            results = found.results
            accents = found.accents
            estimates = found.estimates
            kept = Cards.keptWords()
        }
    }

    /// The kanji at the cursor, or over the selection, as the field stood when the sheet
    /// opened; the cursor then right after it.
    private func insert(_ kanji: String) {
        let result = Insertion.insert(kanji, into: query, replacing: utf16Range(selectionAtParts))
        query = result.text
        let cursor = String.Index(utf16Offset: result.cursor, in: result.text)
        Task { @MainActor in selection = TextSelection(insertionPoint: cursor) }
    }

    private func utf16Range(_ selection: TextSelection?) -> Range<Int>? {
        guard case .selection(let range) = selection?.indices, range.upperBound <= query.endIndex
        else { return nil }
        return range.lowerBound.utf16Offset(in: query)..<range.upperBound.utf16Offset(in: query)
    }

    private func partsButton() -> SearchFieldButton {
        if let fieldButton { return fieldButton }
        let button = SearchFieldButton(
            symbol: "square.grid.3x3.square",
            label: String(localized: "Kanji by parts", bundle: .module)
        ) {
            selectionAtParts = selection
            buildingKanji = true
        }
        fieldButton = button
        return button
    }
}

/// What a search finds, with the pitch of each result: the dictionary's, or an estimate.
private struct Found: Sendable {
    var results: [DictionaryEntry]
    var accents: [Int: PitchAccent] = [:]
    var estimates: [Int: [PitchPhrase]] = [:]
}
