import SwiftUI
import YomidoriCore
import YomidoriDictionary

/// The landing screen: what is due and what waits, then the cards by stack.
struct CardsView: View {
    @State private var cards: [Card] = []
    @State private var dueCount = 0
    @State private var collections: [Collection] = []
    /// The collections shown; none chosen means all cards.
    @State private var chosen: Set<UUID> = []

    var body: some View {
        List {
            Section {
                if dueCount > 0 {
                    NavigationLink(value: Screen.review) {
                        Label {
                            Text("Review \(dueCount)", bundle: .module)
                        } icon: {
                            Image(systemName: "checkmark.rectangle.stack")
                        }
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Palette.nightGreen)
                    }
                } else {
                    Text("Nothing due. Read on.", bundle: .module)
                        .foregroundStyle(.secondary)
                }
                let waiting = cards.filter(\.isWaiting).count
                if waiting > 0 {
                    NavigationLink(value: Screen.lesson) {
                        Label {
                            Text("Lesson · \(waiting) waiting", bundle: .module)
                        } icon: {
                            Image(systemName: "book")
                        }
                        .font(.title3)
                    }
                }
                NavigationLink(value: Screen.collections) {
                    Label {
                        Text("Collections", bundle: .module)
                    } icon: {
                        Image(systemName: "books.vertical")
                    }
                }
            }
            let shown = cards.filter {
                chosen.isEmpty || !chosen.isDisjoint(with: $0.collectionIDs)
            }
            if !shown.isEmpty {
                Section {
                    RankCounts(cards: shown)
                }
            }
            stack(shown.filter(\.isInReview), header: Text("In review", bundle: .module))
            stack(shown.filter(\.isWaiting), header: Text("Waiting", bundle: .module))
            stack(shown.filter(\.shelved), header: Text("Shelved", bundle: .module))
            if cards.isEmpty {
                Text("No cards yet. Tap a word under a page and keep it.", bundle: .module)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(Text(verbatim: "ヨミドリ"))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if !collections.isEmpty {
                    CollectionFilter(collections: collections, chosen: $chosen)
                }
                NavigationLink(value: Screen.settings) {
                    Label {
                        Text("Settings", bundle: .module)
                    } icon: {
                        Image(systemName: "gearshape")
                    }
                }
                NavigationLink(value: Screen.about) {
                    Label {
                        Text("About", bundle: .module)
                    } icon: {
                        Image(systemName: "info.circle")
                    }
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
        dueCount = Cards.dueItems(at: Date()).count
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
            RankName(rank: card.rank)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
