import SwiftUI
import YomidoriCore
import YomidoriDictionary

/// The landing screen: what is due, then the cards kept so far, newest first.
struct CardsView: View {
    @State private var cards: [Card] = []
    @State private var dueCount = 0

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
            }
            Section {
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
            } header: {
                Text("Cards", bundle: .module)
            }
        }
        .navigationTitle(Text(verbatim: "ヨミドリ"))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
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

    private func reload() {
        cards = (Cards.store?.cards() ?? []).sorted { $0.created > $1.created }
        dueCount = Cards.dueItems(at: Date()).count
    }
}
