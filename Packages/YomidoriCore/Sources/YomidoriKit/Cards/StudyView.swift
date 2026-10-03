import SwiftUI
import YomidoriCore

/// The study tab: what is due, what waits for a lesson, and where the cards stand by rank.
struct StudyView: View {
    @State private var cards: [Card] = []
    @State private var dueCount = 0
    @State private var upcoming = Upcoming()

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
            if !upcoming.isEmpty {
                Section {
                    UpcomingReviews(upcoming: upcoming)
                } header: {
                    Text("Coming up", bundle: .module)
                } footer: {
                    Text(
                        // swiftlint:disable:next line_length
                        "Questions due by quarter day, in their ranks' colors; now's with what is overdue. Touch a bar for its numbers.",
                        bundle: .module)
                }
            }
            if !cards.isEmpty {
                Section {
                    RankChart(cards: cards)
                    NavigationLink(value: Screen.progress) {
                        Label {
                            Text("Progress", bundle: .module)
                        } icon: {
                            Image(systemName: "chart.xyaxis.line")
                        }
                    }
                } header: {
                    Text("Ranks", bundle: .module)
                }
            }
        }
        .navigationTitle(Text("Study", bundle: .module))
        .onAppear(perform: reload)
        .onReceive(Cards.changes(of: [.card])) { _ in reload() }
    }

    private func reload() {
        Cards.snapshotRanks()
        cards = Cards.store?.cards() ?? []
        dueCount = Cards.dueItems(at: Date()).count
        upcoming = Upcoming.of(
            cards, from: Date(), days: 7, asksPitch: { !Cards.accents(of: $0).isEmpty })
    }
}
