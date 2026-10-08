import SwiftUI
import YomidoriCore
import YomidoriDictionary

/// The cards in sections — by rank, or by the month they were kept or last changed, each
/// section folding away — filtered by collection and by kind of word, with the way to the
/// collections themselves. Several can be picked at once and put in a collection or taken
/// out of one together: on the phone through *Select*, on the Mac by picking several rows.
struct CardsView: View {
    @State private var cards: [Card] = []
    @State private var collections: [Collection] = []
    @AppStorage(SettingsKey.cardSort) private var sort: CardSort = .rank
    @AppStorage(SettingsKey.cardWordClass) private var wordClassName = ""
    /// The kind of word shown; nil for every kind. Kept as its name, so the default is a
    /// string.
    private var wordClass: Binding<WordClass?> {
        Binding(
            get: { WordClass(rawValue: wordClassName) },
            set: { wordClassName = $0?.rawValue ?? "" })
    }
    /// Each card's kinds of word, read off the dictionary once per card.
    @State private var classes: [UUID: Set<WordClass>] = [:]
    /// The sections folded away, by their group.
    @State private var folded: Set<CardSort.Group> = []
    /// The collections shown; none chosen means all cards.
    @State private var chosen: Set<UUID> = []
    /// Only the cards in no collection, the ones to tidy.
    @State private var unfiled = false
    /// The cards picked: on the Mac the selection, one card or several; on the phone the
    /// ones ticked while selecting.
    @State private var picked: Set<UUID> = []

    /// The card opened in a split's detail column, over whatever was pushed there.
    @State private var detailPath = NavigationPath()
    /// How deep the detail's stack stood when it last said: a pop empties the list's
    /// selection on its way out, before the stack reports the pop, and that selection is
    /// put back, or the reader came back to no card at all.
    @State private var detailDepth = 0
    /// The selection as it last stood, for the frame a pop empties it.
    @State private var pickedBefore: Set<UUID> = []
    @EnvironmentObject private var taps: TabTaps

    var body: some View {
        #if os(macOS)
        split
        #else
        if sizeClass == .regular {
            // Room for two columns: the list stays, the card opens beside it.
            PadColumns {
                ScrollViewReader { proxy in
                    list.scrollsToTopOnReselect(of: .cards, with: proxy)
                }
            } detail: {
                NavigationStack(path: $detailPath) {
                    detail.appDestinations()
                }
            }
            .onChange(of: picked) { old, new in cardChosen(from: old, to: new) }
            .onChange(of: detailPath.count) { _, depth in detailDepth = depth }
            .onReceive(AppCommands.shared.$backAsked.dropFirst()) { _ in back() }
        } else {
            ScrollViewReader { proxy in
                list.scrollsToTopOnReselect(of: .cards, with: proxy)
            }
        }
        #endif
    }

    /// The cards the filters let through, in the order the list shows them.
    private var shown: [Card] {
        let inCollections = unfiled ? loose : cards.filter { $0.isIn(anyOf: chosen) }
        guard let wordClass = wordClass.wrappedValue else { return inCollections }
        return inCollections.filter { classes[$0.id]?.contains(wordClass) ?? false }
    }

    private var order: some View {
        CardListOrder(sort: $sort, wordClass: wordClass)
    }

    /// The cards in none of the collections there are.
    private var loose: [Card] {
        let existing = Set(collections.map(\.id))
        return cards.filter { $0.isInNone(of: existing) }
    }

    private var filter: some View {
        CollectionFilter(
            collections: collections, chosen: $chosen, unfiled: $unfiled,
            unfiledCount: loose.count)
    }

    @ViewBuilder private var stacks: some View {
        ForEach(sort.sections(shown), id: \.group) { section in
            stack(section)
        }
    }

    private func stack(_ section: CardSort.Section) -> some View {
        let isFolded = folded.contains(section.group)
        return Section {
            if !isFolded {
                ForEach(section.cards) { card in
                    row(card)
                        // The pointer's way, and a finger's: asked first, as the Mac's ⌫
                        // is, since a menu's tap is lighter than a swipe's.
                        .contextMenu {
                            Button(role: .destructive) {
                                askedToForget = card
                            } label: {
                                Label {
                                    Text("Forget…", bundle: .module)
                                } icon: {
                                    Image(systemName: "trash")
                                }
                            }
                        }
                }
            }
        } header: {
            CardSectionHeader(
                group: section.group, count: section.cards.count,
                collapsed: Binding(
                    get: { isFolded },
                    set: { fold in
                        if fold {
                            folded.insert(section.group)
                        } else {
                            folded.remove(section.group)
                        }
                    }))
        }
    }

    @ViewBuilder private func row(_ card: Card) -> some View {
        #if os(macOS)
        CardRow(card: card).tag(card.id)
        #else
        // Forgotten by a swipe, a swipe action and not the list's own delete: that one
        // puts its red circles on every row the moment selecting starts, before they can
        // be told to stay away.
        if sizeClass == .regular {
            CardRow(card: card).tag(card.id).swipeActions(edge: .trailing) {
                forget(card)
            }
        } else {
            NavigationLink(value: card) { CardRow(card: card) }
                .swipeActions(edge: .trailing) { forget(card) }
        }
        #endif
    }

    /// The card a row's menu asked to forget, until it is answered for.
    @State private var askedToForget: Card?

    #if os(iOS)
    @ViewBuilder private func forget(_ card: Card) -> some View {
        if !selecting {
            Button(role: .destructive) {
                Cards.write { try Cards.store?.remove(card) }
                reload()
            } label: {
                Label {
                    Text("Forget", bundle: .module)
                } icon: {
                    Image(systemName: "trash")
                }
            }
        }
    }
    #endif

    #if os(iOS)
    @State private var editMode: EditMode = .inactive
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var selecting: Bool { editMode.isEditing }

    private var list: some View {
        List(selection: $picked) {
            if !selecting {
                Section {
                    if sizeClass == .regular {
                        Button {
                            detailPath = NavigationPath()
                            detailPath.append(Screen.collections)
                        } label: {
                            collectionsLabel
                        }
                    } else {
                        NavigationLink(value: Screen.collections) { collectionsLabel }
                    }
                }
                .id(TabTop.id)
            }
            stacks
            if cards.isEmpty {
                Text("No cards yet. Tap a word under a page and keep it.", bundle: .module)
                    .foregroundStyle(.secondary)
            }
        }
        .environment(\.editMode, $editMode)
        .modifier(ForgetOneDialog(card: $askedToForget, forgotten: reload))
        .navigationTitle(Text("Cards", bundle: .module))
        .toolbar {
            if !cards.isEmpty {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation {
                            editMode = selecting ? .inactive : .active
                            picked = []
                        }
                    } label: {
                        if selecting {
                            Text("Done", bundle: .module)
                        } else {
                            Text("Select", bundle: .module)
                        }
                    }
                }
            }
            if selecting {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        picked = picked.count == shown.count ? [] : Set(shown.map(\.id))
                    } label: {
                        if picked.count == shown.count, !shown.isEmpty {
                            Text("None", bundle: .module)
                        } else {
                            Text("All", bundle: .module)
                        }
                    }
                }
            } else {
                ToolbarItemGroup(placement: .primaryAction) {
                    if !collections.isEmpty { filter }
                    order
                }
            }
        }
        // The batch, over the tab bar, while selecting.
        .safeAreaInset(edge: .bottom) {
            if selecting {
                CardsBatch(picked: $picked, cards: cards, collections: collections)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(.bar)
            }
        }
        .onAppear {
            reload()
            if DemoMode.selecting, !selecting {
                editMode = .active
                // Picked once the list is selecting, or entering the mode clears them.
                let few = Set(shown.filter(\.isInReview).prefix(3).map(\.id))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { picked = few }
            }
        }
        .onReceive(Cards.changes(of: [.card, .collection])) { _ in reload() }
    }
    #endif

    #if os(macOS)
    @State private var forgetting = false

    /// With room: the list on the left, the card on the right, the arrow keys moving
    /// through the stacks, ⌫ forgetting what is picked after asking. Several picked, with
    /// ⌘ or ⇧, and the right side is what is done to them together.
    private var split: some View {
        HSplitView {
            List(selection: $picked) {
                Section {
                    Button {
                        detailPath = NavigationPath()
                        detailPath.append(Screen.collections)
                    } label: {
                        // A row to the eye and the pointer, chevron and all, not a label
                        // clickable only on its letters.
                        HStack {
                            collectionsLabel
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                stacks
                if cards.isEmpty {
                    Text("No cards yet. Select a word under a page and keep it.", bundle: .module)
                        .foregroundStyle(.secondary)
                }
            }
            .onDeleteCommand { forgetting = !picked.isEmpty }
            .modifier(ForgetOneDialog(card: $askedToForget, forgotten: reload))
            .forgetCardsDialog(isPresented: $forgetting, picked: $picked, cards: cards)
            .safeAreaInset(edge: .top) {
                HStack {
                    Spacer()
                    if !collections.isEmpty { filter }
                    order
                }
                .controlSize(.small)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.bar)
            }
            .frame(minWidth: 280, idealWidth: 340, maxWidth: 480, maxHeight: .infinity)
            NavigationStack(path: $detailPath) {
                detail.appDestinations()
            }
            .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
        }
        .fittingWindow()
        .navigationTitle(Text("Cards", bundle: .module))
        .onChange(of: picked) { old, new in cardChosen(from: old, to: new) }
        .onChange(of: detailPath.count) { _, depth in detailDepth = depth }
        .onReceive(AppCommands.shared.$backAsked.dropFirst()) { _ in back() }
        .onAppear(perform: reload)
        .onReceive(Cards.changes(of: [.card, .collection])) { _ in reload() }
    }

    #endif

    /// What the detail shows: the cards picked — or, for the one frame in which a pop has
    /// emptied the selection and the stack has not yet said so, the cards picked before,
    /// so the card stays put, scrolled as it was, rather than going and coming back.
    private var shownSelection: Set<UUID> {
        picked.isEmpty && detailPath.isEmpty && detailDepth > 0 ? pickedBefore : picked
    }

    @ViewBuilder private var detail: some View {
        let picked = shownSelection
        if picked.count == 1, let card = cards.first(where: { picked.contains($0.id) }) {
            CardView(card: card).id(card.id)
        } else if picked.count > 1 {
            CardsBatch(picked: $picked, cards: cards, collections: collections)
                .frame(maxWidth: 360)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Text("Select a card.", bundle: .module)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var collectionsLabel: some View {
        Label {
            Text("Collections", bundle: .module)
        } icon: {
            Image(systemName: "books.vertical")
        }
    }
}

// MARK: The cards and their kinds, loaded

extension CardsView {
    /// ⌘[ while Cards shows: the screen over the card goes.
    private func back() {
        guard taps.shown == .cards, !detailPath.isEmpty else { return }
        detailPath.removeLast()
    }

    /// A card chosen: the stack shows it, over whatever was pushed. A selection emptied by
    /// the stack's own pop — the path already empty, its last word still a depth — is the
    /// reader's card still, and stays.
    private func cardChosen(from old: Set<UUID>, to new: Set<UUID>) {
        if new.isEmpty, !old.isEmpty, detailPath.isEmpty, detailDepth > 0 {
            picked = old
            return
        }
        pickedBefore = new
        detailPath = NavigationPath()
    }

    /// A split's detail: the one card picked, what is done to several, or a word to pick one.

    func reload() {
        cards = (Cards.store?.cards() ?? []).sorted { $0.created > $1.created }
        collections = Cards.collections?.collections() ?? []
        // The kinds of word of cards not seen before, from the first sense of each entry; a
        // card kept without its entry's id is looked up by its word. Off the main thread: a
        // thousand cards are a thousand dictionary queries, a second's worth.
        let unknown = cards.filter { classes[$0.id] == nil }
        guard !unknown.isEmpty, let dictionary = JMdict.bundled else { return }
        Task.detached(priority: .userInitiated) {
            var found: [UUID: Set<WordClass>] = [:]
            for card in unknown {
                let entry =
                    card.entryID.flatMap(dictionary.entry(withID:))
                    ?? dictionary.entry(headword: card.headword, reading: card.reading)
                found[card.id] = WordClass.of(
                    partsOfSpeech: entry?.senses.first?.partsOfSpeech ?? [])
            }
            let classes = found
            await MainActor.run { self.classes.merge(classes) { _, new in new } }
        }
        // A card gone, here or on another device, is no longer picked.
        picked.formIntersection(Set(cards.map(\.id)))
        // The last loose card filed: all cards again, not an empty list.
        if unfiled, loose.isEmpty { unfiled = false }
    }
}

struct CardRow: View {
    let card: Card

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(japanese: card.headword)
                .font(.title3)
            Text(japanese: card.reading)
                .foregroundStyle(Palette.nightGreen)
            Spacer()
            RankMark(rank: card.rank, size: 22)
                .accessibilityLabel(RankName.text(for: card.rank))
        }
    }
}

/// The question before one card goes from its row's menu.
private struct ForgetOneDialog: ViewModifier {
    @Binding var card: Card?
    let forgotten: () -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(
            Text("Forget this card?", bundle: .module),
            isPresented: Binding(get: { card != nil }, set: { if !$0 { card = nil } }),
            presenting: card
        ) { card in
            Button(role: .destructive) {
                Cards.write { try Cards.store?.remove(card) }
                forgotten()
            } label: {
                Text("Forget", bundle: .module)
            }
        } message: { _ in
            Text("Their sentences and their answers go with them.", bundle: .module)
        }
    }
}
