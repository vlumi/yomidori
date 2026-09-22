import SwiftUI
import YomidoriCore

/// The study tab: what is due, what waits for a lesson, and where the cards stand by rank.
struct StudyView: View {
    @State private var cards: [Card] = []
    @State private var dueCount = 0

    var body: some View {
        ScrollViewReader { proxy in
            list.scrollsToTopOnReselect(of: .study, with: proxy)
        }
    }

    private var list: some View {
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
                NavigationLink(value: Screen.lesson) {
                    Label {
                        Text("Lesson · \(waiting) waiting", bundle: .module)
                    } icon: {
                        Image(systemName: "book")
                    }
                    .font(.title3)
                }
                .disabled(waiting == 0)
            }
            .id(TabTop.id)
            if !cards.isEmpty {
                Section {
                    RankCounts(cards: cards)
                } header: {
                    Text("Ranks", bundle: .module)
                }
            }
        }
        .navigationTitle(Text("Study", bundle: .module))
        .onAppear {
            cards = Cards.store?.cards() ?? []
            dueCount = Cards.dueItems(at: Date()).count
        }
    }
}
