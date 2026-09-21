import SwiftUI
import YomidoriCore
import YomidoriDictionary

/// The cards kept so far, newest first: the word, its reading, how often it was
/// met. Swipe to remove. Tap for the card itself.
struct CardsView: View {
    @State private var cards: [Card] = []
    @State private var dueCount = 0

    var body: some View {
        List {
            if cards.isEmpty {
                Text("No cards yet. Tap a word under a page and keep it.", bundle: .module)
                    .foregroundStyle(.secondary)
            }
            ForEach(cards) { card in
                NavigationLink(value: card) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(verbatim: card.headword)
                            .font(.title3)
                        Text(verbatim: card.reading)
                            .foregroundStyle(Palette.nightGreen)
                        Spacer()
                        Text(verbatim: "\(card.sightings.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { offsets in
                for index in offsets {
                    try? Cards.store?.remove(cards[index])
                }
                reload()
            }
        }
        .navigationTitle(Text("Cards", bundle: .module))
        .toolbar {
            if dueCount > 0 {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(value: Screen.review) {
                        Label {
                            Text("Review \(dueCount)", bundle: .module)
                        } icon: {
                            Image(systemName: "checkmark.rectangle.stack")
                        }
                    }
                }
            }
        }
        .onAppear(perform: reload)
    }

    private func reload() {
        cards = (Cards.store?.cards() ?? []).sorted { $0.created > $1.created }
        dueCount = Cards.store?.dueItems(at: Date()).count ?? 0
    }
}
