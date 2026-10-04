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

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    var body: some View {
        #if os(macOS)
        split
        #else
        if sizeClass == .regular {
            // Room for two columns: the history or the results stay, the entry opens beside,
            // picked as on the Mac, since a list that selects takes the taps a link would.
            NavigationSplitView {
                ScrollViewReader { proxy in
                    searching(pickingList).scrollsToTopOnReselect(of: .search, with: proxy)
                }
            } detail: {
                NavigationStack(path: $detailPath) {
                    Group {
                        if let picked {
                            EntryView(entry: picked).id(picked.id)
                        } else {
                            Text("A result or a word looked up opens here.", bundle: .module)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .appDestinations()
                }
            }
            .onChange(of: pickedResult) { _, id in pick(result: id) }
        } else {
            ScrollViewReader { proxy in
                list.scrollsToTopOnReselect(of: .search, with: proxy)
            }
        }
        #endif
    }

    /// A split's entry column: the entry picked, a result or a line of the history, with
    /// what it opens pushed over it.
    @State private var detailPath = NavigationPath()
    @State private var picked: DictionaryEntry?
    /// The result the arrow keys and a tap choose, by id.
    @State private var pickedResult: Int?

    #if os(macOS)
    @AppStorage(SettingsKey.historyShown) private var historyShown = true

    /// With room, three columns: the history, folded away or not; the results under the
    /// field; and the entry picked from either, with what it opens. A plain split, not a
    /// navigation one: the sidebar of the sections is the window's, and a second would put
    /// two sidebar toggles in the toolbar, which AppKit refuses.
    @FocusState private var fieldFocused: Bool

    private var split: some View {
        searching(splitColumns.fittingWindow())
            // ⌘F: the field, from anywhere in the dictionary.
            .background {
                Button {
                    fieldFocused = true
                } label: {
                    EmptyView()
                }
                .keyboardShortcut("f", modifiers: .command)
                .frame(width: 0, height: 0)
                .opacity(0)
            }
    }

    private var field: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(
                text: $query, selection: $selection,
                prompt: Text("Kana, kanji, or English", bundle: .module)
            ) {
                Text("Dictionary", bundle: .module)
            }
            .labelsHidden()
            .textFieldStyle(.plain)
            .focused($fieldFocused)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(Text("Clear the search (⌘F to type again)", bundle: .module))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 7))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var splitColumns: some View {
        HSplitView {
            if historyShown {
                historyColumn
                    .frame(minWidth: 180, idealWidth: 260, maxWidth: 380, maxHeight: .infinity)
            }
            column(
                Text("Search", bundle: .module),
                buttons: {
                    if !historyShown {
                        Button {
                            withAnimation(.snappy) { historyShown = true }
                        } label: {
                            Label {
                                Text("History", bundle: .module)
                            } icon: {
                                Image(systemName: "clock.arrow.circlepath")
                            }
                        }
                        .help(Text("Show the words looked up", bundle: .module))
                    }
                    // The parts: a sheet that types into the field.
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
                    .help(Text("Find a kanji by its parts", bundle: .module))
                }
            ) {
                field
                resultsList
            }
            .frame(minWidth: 240, idealWidth: 320, maxWidth: 480, maxHeight: .infinity)
            NavigationStack(path: $detailPath) {
                Group {
                    if let picked {
                        EntryView(entry: picked).id(picked.id)
                    } else {
                        Text("A result or a word looked up opens here.", bundle: .module)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .appDestinations()
            }
            .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: pickedResult) { _, id in pick(result: id) }
    }

    #endif

    /// A result picked: the entry column shows it, over whatever it had opened.
    private func pick(result id: Int?) {
        guard let entry = results.first(where: { $0.id == id }) else { return }
        picked = entry
        detailPath = NavigationPath()
    }

    /// A line of the history opened in the entry column.
    private func open(_ entry: DictionaryEntry) {
        pickedResult = nil
        picked = entry
        detailPath = NavigationPath()
    }

    #if os(iOS)
    /// The phone's list with the Mac's picking: the history's lines open the entry column,
    /// the results are picked by selection.
    private var pickingList: some View {
        List(selection: $pickedResult) {
            if SearchQuery.kind(of: query) == .empty {
                LookupHistoryView(generation: historyGeneration, open: open)
                    .id(TabTop.id)
            } else if results.isEmpty {
                Text("No matches.", bundle: .module)
                    .foregroundStyle(.secondary)
            }
            ForEach(results) { entry in
                row(for: entry)
                    .tag(entry.id)
            }
        }
    }
    #endif

    /// A result's row: the entry with its pitch, known or worked out, and whether it is kept.
    private func row(for entry: DictionaryEntry) -> EntryRow {
        EntryRow(
            entry: entry, accent: accents[entry.id], estimate: estimates[entry.id] ?? [],
            kept: kept.contains(entry.wordKey))
    }

    private var resultRows: some View {
        ForEach(results) { entry in
            NavigationLink(value: entry) {
                row(for: entry)
            }
        }
    }

    private var list: some View {
        searching(
            List {
                if SearchQuery.kind(of: query) == .empty {
                    LookupHistoryView(generation: historyGeneration)
                        .id(TabTop.id)
                } else if results.isEmpty {
                    Text("No matches.", bundle: .module)
                        .foregroundStyle(.secondary)
                }
                resultRows
            }
            .phoneSearchBarMargin(searching))
    }

    /// What both layouts share: the field, its focus and cursor, the parts button in the
    /// field on the phone, and the search itself.
    private func searching<Content: View>(_ content: Content) -> some View {
        content
            .phoneSearchField(text: $query, focused: $searching, selection: $selection)
            // The parts sheet opens from a button at the end of the search box, put there once
            // the field has the keyboard.
            .task(id: searching) {
                if searching { await partsButton().install() }
            }
            // Switched to, the tab is for typing: the field takes the keyboard at once; and
            // once more a moment later, for the Mac, where the field is not there yet when
            // the switch happens.
            .onChange(of: taps.shown, initial: true) { _, shown in
                guard shown == .search else { return }
                focusField()
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(150))
                    if taps.shown == .search { focusField() }
                }
            }
            .navigationTitle(Text("Dictionary", bundle: .module))
            .toolbar {
                // The phone's Clear; the Mac's stands under its history column.
                #if os(iOS)
                if SearchQuery.kind(of: query) == .empty,
                    Cards.lookups?.lookups().isEmpty == false
                {
                    ToolbarItem(placement: .primaryAction) {
                        ClearHistoryButton(generation: $historyGeneration)
                    }
                }
                #endif
            }
            .sheet(isPresented: $buildingKanji, onDismiss: { searching = true }) {
                KanjiByPartsView(pick: insert)
                    .sheetSize(width: 560, height: 640)
            }
            .task(id: query) { await search() }
    }

    private func focusField() {
        #if os(macOS)
        fieldFocused = true
        #else
        searching = true
        #endif
    }

    /// A moment after the typing, off the main thread.
    private func search() async {
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

#if os(macOS)
extension SearchView {
    /// The field, over the results it fills: a Mac's search field, in the column and not
    /// the window's toolbar, so it stands over what it searches.
    /// A column under its title, with its buttons at the right of the title. The window's
    /// toolbar is left to the field: items of its own beside an entry's is what AppKit
    /// refuses.
    private func column<Buttons: View, Content: View>(
        _ title: Text, @ViewBuilder buttons: () -> Buttons = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            HStack {
                title.font(.headline)
                Spacer()
                buttons()
                    .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            Divider()
            content()
        }
    }

    private var historyColumn: some View {
        column(
            Text("History", bundle: .module),
            buttons: {
                Button {
                    withAnimation(.snappy) { historyShown = false }
                } label: {
                    Label {
                        Text("Hide", bundle: .module)
                    } icon: {
                        Image(systemName: "sidebar.leading")
                    }
                }
                .labelStyle(.iconOnly)
                .help(Text("Hide the words looked up", bundle: .module))
            }
        ) {
            List {
                LookupHistoryView(generation: historyGeneration, open: open)
            }
            .safeAreaInset(edge: .bottom) {
                if Cards.lookups?.lookups().isEmpty == false {
                    HStack {
                        Spacer()
                        ClearHistoryButton(generation: $historyGeneration)
                            .controlSize(.small)
                    }
                    .padding(8)
                    .background(.bar)
                }
            }
        }
    }

    /// The results, one chosen at a time by a click or the arrow keys.
    private var resultsList: some View {
        List(selection: $pickedResult) {
            if SearchQuery.kind(of: query) == .empty {
                Text(
                    "Kana or kanji finds words that start so; anything else searches the English meanings.",
                    bundle: .module
                )
                .foregroundStyle(.secondary)
            } else if results.isEmpty {
                Text("No matches.", bundle: .module)
                    .foregroundStyle(.secondary)
            }
            ForEach(results) { entry in
                row(for: entry)
                    .tag(entry.id)
            }
        }
    }
}
#endif
