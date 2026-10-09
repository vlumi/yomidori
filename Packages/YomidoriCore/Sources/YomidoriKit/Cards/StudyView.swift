import SwiftUI
import YomidoriCore

/// The study tab: what is due, what waits for a lesson, and where the cards stand by rank.
struct StudyView: View {
    @State private var cards: [Card] = []
    @State private var dueCount = 0
    @Environment(\.scenePhase) private var scenePhase
    @State private var upcoming = Upcoming()
    /// All the questions, or one: what Coming up and Ranks show.
    @State private var question: Question?
    /// Coming up's bars colored by the cards' ranks, or by what each question asks.
    @AppStorage(SettingsKey.upcomingByQuestion) private var byQuestion = false
    /// How far Coming up looks: a week by quarter days, or a month by days.
    @AppStorage(SettingsKey.upcomingDays) private var days = 7
    /// Opens a screen over this tab's root: a button, not a link, so a list row doesn't
    /// turn the fat button back into a row with a chevron.
    @EnvironmentObject private var taps: TabTaps

    var body: some View {
        ScrollViewReader { proxy in
            list.scrollsToTopOnReselect(of: .study, with: proxy)
        }
    }

    private var list: some View {
        List {
            Section {
                let waiting = cards.filter(\.isWaiting).count
                HStack(spacing: 12) {
                    Button {
                        taps.open(.review, in: .study)
                    } label: {
                        StudyButtons.review(due: dueCount)
                    }
                    .buttonStyle(FatButtonStyle(color: StudyButtons.reviewColor))
                    .disabled(dueCount == 0)
                    Button {
                        taps.open(.lesson, in: .study)
                    } label: {
                        StudyButtons.lesson(waiting: waiting)
                    }
                    .buttonStyle(FatButtonStyle(color: StudyButtons.lessonColor))
                    .disabled(waiting == 0)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
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
                    if question == nil {
                        HStack {
                            Spacer()
                            Picker(selection: $byQuestion) {
                                Text("Ranks", bundle: .module).tag(false)
                                Text("Questions", bundle: .module).tag(true)
                            } label: {
                                Text("Colors", bundle: .module)
                            }
                            .pickerStyle(.segmented)
                            .controlSize(.mini)
                            .fixedSize()
                        }
                    }
                } header: {
                    HStack {
                        Text("Coming up", bundle: .module)
                        Spacer()
                        Picker(selection: $days) {
                            Text("7 days", bundle: .module).tag(7)
                            Text("30 days", bundle: .module).tag(30)
                        } label: {
                            Text("Days ahead", bundle: .module)
                        }
                        .pickerStyle(.segmented)
                        .controlSize(.mini)
                        .fixedSize()
                        .textCase(nil)
                    }
                } footer: {
                    if days > 7 {
                        Text(
                            // swiftlint:disable:next line_length
                            "Questions due by day; today's with what is overdue. Touch a bar for its numbers.",
                            bundle: .module)
                    } else if question == nil && byQuestion {
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
        // What is due moves with the clock: counted again on return to the front and by
        // the minute, not only when a card changes.
        .onChange(of: scenePhase) { _, phase in if phase == .active { reload() } }
        .onReceive(DueClock.ticks) { _ in reload() }
        .onChange(of: question) { reload() }
        .onChange(of: days) { reload() }
        .onReceive(Cards.changes(of: [.card])) { _ in reload() }
    }

    private func reload() {
        Cards.snapshotRanks()
        cards = Cards.store?.cards() ?? []
        dueCount = Cards.dueItems(at: Date()).count
        upcoming = Upcoming.of(
            cards, from: Date(), days: days, slotsPerDay: days > 7 ? 1 : Upcoming.slotsPerDay,
            question: question, asksPitch: { !Cards.accents(of: $0).isEmpty })
    }
}
