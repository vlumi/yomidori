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
        ScrollViewReader { proxy in
            list.scrollsToTopOnReselect(of: .cards, with: proxy)
        }
    }

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
            let shown = cards.filter {
                chosen.isEmpty || !chosen.isDisjoint(with: $0.collectionIDs)
            }
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
    }

    @ViewBuilder private func stack(_ cards: [Card], header: Text) -> some View {
        if !cards.isEmpty {
            Section {
                ForEach(cards) { card in
                    NavigationLink(value: card) { CardRow(card: card) }
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
            Text(verbatim: card.headword)
                .font(.title3)
            Text(verbatim: card.reading)
                .foregroundStyle(Palette.nightGreen)
            Spacer()
            HStack(spacing: 6) {
                RankMark(rank: card.rank, size: 22)
                RankName(rank: card.rank)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
