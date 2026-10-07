import SwiftUI
import YomidoriCore

/// The study tab: what is due, what waits for a lesson, and where the cards stand by rank.
struct StudyView: View {
    @State private var cards: [Card] = []
    @State private var dueCount = 0
    @State private var upcoming = Upcoming()
    /// All the questions, or one: what Coming up and Ranks show.
    @State private var question: Question?
    /// Coming up's bars colored by the cards' ranks, or by what each question asks.
    @AppStorage(SettingsKey.upcomingByQuestion) private var byQuestion = false

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
                        StudyLabel.review(dueCount)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Palette.nightGreen)
                    }
                } else {
                    StudyLabel.nothingDue
                }
                let waiting = cards.filter(\.isWaiting).count
                NavigationLink(value: Screen.lesson) {
                    StudyLabel.lesson(waiting: waiting)
                        .font(.title3)
                }
                .disabled(waiting == 0)
            }
            .id(TabTop.id)
            if !cards.isEmpty {
                Section {
                    QuestionPicker(question: $question)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
            }
            if !upcoming.isEmpty {
                Section {
                    UpcomingReviews(
                        upcoming: upcoming,
                        stacking: question == nil && byQuestion ? .question : .rank)
                } header: {
                    HStack {
                        Text("Coming up", bundle: .module)
                        Spacer()
                        if question == nil {
                            Picker(selection: $byQuestion) {
                                Text("Ranks", bundle: .module).tag(false)
                                Text("Questions", bundle: .module).tag(true)
                            } label: {
                                Text("Colors", bundle: .module)
                            }
                            .pickerStyle(.segmented)
                            .controlSize(.mini)
                            .fixedSize()
                            .textCase(nil)
                        }
                    }
                } footer: {
                    if question == nil && byQuestion {
                        Text(
                            // swiftlint:disable:next line_length
                            "Questions due by quarter day, in the colors of what they ask; now's with what is overdue. Touch a bar for its numbers.",
                            bundle: .module)
                    } else {
                        Text(
                            // swiftlint:disable:next line_length
                            "Questions due by quarter day, in their ranks' colors; now's with what is overdue. Touch a bar for its numbers.",
                            bundle: .module)
                    }
                }
            }
            if !cards.isEmpty {
                Section {
                    RankChart(cards: cards, question: question)
                } header: {
                    Text("Ranks", bundle: .module)
                }
            }
        }
        .navigationTitle(Text("Study", bundle: .module))
        .toolbar {
            if !cards.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(value: Screen.progress) {
                        Label {
                            Text("Progress", bundle: .module)
                        } icon: {
                            Image(systemName: "chart.xyaxis.line")
                        }
                    }
                }
            }
        }
        .onAppear(perform: reload)
        .onChange(of: question) { reload() }
        .onReceive(Cards.changes(of: [.card])) { _ in reload() }
    }

    private func reload() {
        Cards.snapshotRanks()
        cards = Cards.store?.cards() ?? []
        dueCount = Cards.dueItems(at: Date()).count
        upcoming = Upcoming.of(
            cards, from: Date(), days: 7, question: question,
            asksPitch: { !Cards.accents(of: $0).isEmpty })
    }
}
