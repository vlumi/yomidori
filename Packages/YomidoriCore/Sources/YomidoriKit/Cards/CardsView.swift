import SwiftUI
import YomidoriCore
import YomidoriDictionary

/// The cards by stack, filtered by collection, with the way to the collections themselves.
/// Several can be picked at once and put in a collection or taken out of one together: on
/// the phone through *Select*, on the Mac by picking several rows.
struct CardsView: View {
    @State private var cards: [Card] = []
    @State private var collections: [Collection] = []
    /// The collections shown; none chosen means all cards.
    @State private var chosen: Set<UUID> = []
    /// Only the cards in no collection, the ones to tidy.
    @State private var unfiled = false
    /// The cards picked: on the Mac the selection, one card or several; on the phone the
    /// ones ticked while selecting.
    @State private var picked: Set<UUID> = []

    /// The card opened in a split's detail column, over whatever was pushed there.
    @State private var detailPath = NavigationPath()

    var body: some View {
        #if os(macOS)
        split
        #else
        if sizeClass == .regular {
            // Room for two columns: the list stays, the card opens beside it.
            NavigationSplitView {
                ScrollViewReader { proxy in
                    list.scrollsToTopOnReselect(of: .cards, with: proxy)
                }
            } detail: {
                NavigationStack(path: $detailPath) {
                    detail.appDestinations()
                }
            }
            // A card chosen: the stack shows it, over whatever was pushed.
            .onChange(of: picked) { _, _ in detailPath = NavigationPath() }
        } else {
            ScrollViewReader { proxy in
                list.scrollsToTopOnReselect(of: .cards, with: proxy)
            }
        }
        #endif
    }

    /// The cards the filter lets through, in the order the list shows them.
    private var shown: [Card] {
        unfiled ? loose : cards.filter { $0.isIn(anyOf: chosen) }
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
        stack(shown.filter(\.isInReview), header: Text("In review", bundle: .module))
        stack(shown.filter(\.isWaiting), header: Text("Waiting", bundle: .module))
        stack(shown.filter(\.shelved), header: Text("Shelved", bundle: .module))
    }

    @ViewBuilder private func stack(_ cards: [Card], header: Text) -> some View {
        if !cards.isEmpty {
            Section {
                ForEach(cards) { card in
                    #if os(macOS)
                    CardRow(card: card).tag(card.id)
                    #else
                    // Forgotten by a swipe, a swipe action and not the list's own delete:
                    // that one puts its red circles on every row the moment selecting
                    // starts, before they can be told to stay away.
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
            } header: {
                header
            }
        }
    }

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

    private func reload() {
        cards = (Cards.store?.cards() ?? []).sorted { $0.created > $1.created }
        collections = Cards.collections?.collections() ?? []
        // A card gone, here or on another device, is no longer picked.
        picked.formIntersection(Set(cards.map(\.id)))
        // The last loose card filed: all cards again, not an empty list.
        if unfiled, loose.isEmpty { unfiled = false }
    }

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
            } else if !collections.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    filter
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
                        collectionsLabel
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
            .forgetCardsDialog(isPresented: $forgetting, picked: $picked, cards: cards)
            .safeAreaInset(edge: .top) {
                if !collections.isEmpty {
                    HStack {
                        Spacer()
                        filter
                            .controlSize(.small)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.bar)
                }
            }
            .frame(minWidth: 280, idealWidth: 340, maxWidth: 480, maxHeight: .infinity)
            NavigationStack(path: $detailPath) {
                detail.appDestinations()
            }
            .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
        }
        .fittingWindow()
        .navigationTitle(Text("Cards", bundle: .module))
        // A card chosen: the stack shows it, over whatever was pushed.
        .onChange(of: picked) { _, _ in detailPath = NavigationPath() }
        .onAppear(perform: reload)
        .onReceive(Cards.changes(of: [.card, .collection])) { _ in reload() }
    }

    #endif

    /// A split's detail: the one card picked, what is done to several, or a word to pick one.
    @ViewBuilder private var detail: some View {
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
