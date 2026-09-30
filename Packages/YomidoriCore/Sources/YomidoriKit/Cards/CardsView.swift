import SwiftUI
import YomidoriCore
import YomidoriDictionary

/// The cards by stack, filtered by collection, with the way to the collections themselves.
struct CardsView: View {
    @State private var cards: [Card] = []
    @State private var collections: [Collection] = []
    /// The collections shown; none chosen means all cards.
    @State private var chosen: Set<UUID> = []

    var body: some View {
        #if os(macOS)
        split
        #else
        ScrollViewReader { proxy in
            list.scrollsToTopOnReselect(of: .cards, with: proxy)
        }
        #endif
    }

    #if os(macOS)
    @State private var selected: UUID?
    @State private var detailPath = NavigationPath()
    @State private var forgetting: Card?

    /// With room: the list on the left, the card on the right, the arrow keys moving
    /// through the stacks, ⌫ forgetting a card after asking.
    private var split: some View {
        HSplitView {
            List(selection: $selected) {
                Section {
                    Button {
                        detailPath = NavigationPath()
                        detailPath.append(Screen.collections)
                    } label: {
                        Label {
                            Text("Collections", bundle: .module)
                        } icon: {
                            Image(systemName: "books.vertical")
                        }
                    }
                    .buttonStyle(.plain)
                }
                let shown = cards.filter { $0.isIn(anyOf: chosen) }
                stack(shown.filter(\.isInReview), header: Text("In review", bundle: .module))
                stack(shown.filter(\.isWaiting), header: Text("Waiting", bundle: .module))
                stack(shown.filter(\.shelved), header: Text("Shelved", bundle: .module))
                if cards.isEmpty {
                    Text("No cards yet. Select a word under a page and keep it.", bundle: .module)
                        .foregroundStyle(.secondary)
                }
            }
            .onDeleteCommand {
                forgetting = cards.first { $0.id == selected }
            }
            .confirmationDialog(
                Text("Forget this card?", bundle: .module), isPresented: forgettingShown,
                presenting: forgetting
            ) { card in
                Button(role: .destructive) {
                    try? Cards.store?.remove(card)
                    if selected == card.id { selected = nil }
                } label: {
                    Text("Forget \(card.headword)", bundle: .module)
                }
            } message: { _ in
                Text("Its sentences and its answers go with it.", bundle: .module)
            }
            .safeAreaInset(edge: .top) {
                if !collections.isEmpty {
                    HStack {
                        Spacer()
                        CollectionFilter(collections: collections, chosen: $chosen)
                            .controlSize(.small)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.bar)
                }
            }
            .frame(minWidth: 280, idealWidth: 340, maxWidth: 480, maxHeight: .infinity)
            NavigationStack(path: $detailPath) {
                Group {
                    if let card = cards.first(where: { $0.id == selected }) {
                        CardView(card: card).id(card.id)
                    } else {
                        Text("Select a card.", bundle: .module)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .appDestinations()
            }
            .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(Text("Cards", bundle: .module))
        // A card chosen: the stack shows it, over whatever was pushed.
        .onChange(of: selected) { _, _ in detailPath = NavigationPath() }
        .onAppear(perform: reload)
        .onReceive(Cards.changes(of: [.card, .collection])) { _ in reload() }
    }

    private var forgettingShown: Binding<Bool> {
        Binding(get: { forgetting != nil }, set: { if !$0 { forgetting = nil } })
    }
    #endif

    private var list: some View {
        List {
            Section {
                NavigationLink(value: Screen.collections) {
                    Label {
                        Text("Collections", bundle: .module)
                    } icon: {
                        Image(systemName: "books.vertical")
                    }
                }
            }
            .id(TabTop.id)
            let shown = cards.filter { $0.isIn(anyOf: chosen) }
            stack(shown.filter(\.isInReview), header: Text("In review", bundle: .module))
            stack(shown.filter(\.isWaiting), header: Text("Waiting", bundle: .module))
            stack(shown.filter(\.shelved), header: Text("Shelved", bundle: .module))
            if cards.isEmpty {
                Text("No cards yet. Tap a word under a page and keep it.", bundle: .module)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(Text("Cards", bundle: .module))
        .toolbar {
            if !collections.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    CollectionFilter(collections: collections, chosen: $chosen)
                }
            }
        }
        .onAppear(perform: reload)
        .onReceive(Cards.changes(of: [.card, .collection])) { _ in reload() }
    }

    @ViewBuilder private func stack(_ cards: [Card], header: Text) -> some View {
        if !cards.isEmpty {
            Section {
                ForEach(cards) { card in
                    #if os(macOS)
                    CardRow(card: card).tag(card.id)
                    #else
                    NavigationLink(value: card) { CardRow(card: card) }
                    #endif
                }
                .onDelete { offsets in
                    for index in offsets {
                        try? Cards.store?.remove(cards[index])
                    }
                    reload()
                }
            } header: {
                header
            }
        }
    }

    private func reload() {
        cards = (Cards.store?.cards() ?? []).sorted { $0.created > $1.created }
        collections = Cards.collections?.collections() ?? []
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
