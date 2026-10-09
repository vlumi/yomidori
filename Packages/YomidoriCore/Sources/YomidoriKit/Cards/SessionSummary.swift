import SwiftUI
import YomidoriCore

/// A card as a sitting left it: where it stood when the sitting began, where it stands
/// now, and how its answers went.
struct SessionCard: Identifiable {
    var card: Card
    let before: Rank
    var good = 0
    var again = 0

    var id: UUID { card.id }
    var after: Rank { card.rank }
    var climbed: Bool { after > before }
    var slipped: Bool { after < before }
}

/// What a sitting of reviews came to, once the queue is empty: how many answered, right and
/// missed, the minutes, each question's share — and every card it touched, the ones that
/// climbed a rank first, each with its answers and where it stands now.
struct SessionSummary: View {
    let session: DayTally
    var cards: [SessionCard] = []
    let done: () -> Void

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Session done", bundle: .module)
                        .font(.largeTitle.weight(.semibold))
                    HStack(alignment: .top) {
                        stat("\(session.total)", Text("Answered", bundle: .module))
                        stat("\(session.rightTotal)", Text("Correct", bundle: .module))
                        stat(
                            "\(session.total - session.rightTotal)", Text("Again", bundle: .module))
                        stat("\(session.seconds / 60)", Text("Minutes", bundle: .module))
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Question.allCases, id: \.self) { question in
                            if let asked = session.answered[question], asked > 0 {
                                HStack {
                                    QuestionTag(question: question)
                                    Spacer()
                                    Text(verbatim: "\(session.right[question] ?? 0) / \(asked)")
                                        .monospacedDigit()
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            group(cards.filter(\.climbed), Text("Promoted", bundle: .module))
            group(cards.filter(\.slipped), Text("Slipped", bundle: .module))
            group(cards.filter { !$0.climbed && !$0.slipped }, Text("Held", bundle: .module))
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: done) {
                Text("Done", bundle: .module).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .controlSize(.large)
            .padding(16)
            .background(Palette.page)
        }
        .tint(Palette.nightGreen)
    }

    @ViewBuilder
    private func group(_ cards: [SessionCard], _ title: Text) -> some View {
        if !cards.isEmpty {
            Section {
                ForEach(cards.sorted { $0.card.headword < $1.card.headword }) { seen in
                    NavigationLink(value: seen.card) { row(seen) }
                }
            } header: {
                title
            }
        }
    }

    /// The word, its answers, and its rank: the one it climbed or slipped to beside the
    /// one it had, or the one it holds.
    private func row(_ seen: SessionCard) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(japanese: seen.card.headword)
                    .font(.headline)
                Text(japanese: seen.card.reading)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(seen.good) good · \(seen.again) again", bundle: .module)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                if seen.after != seen.before {
                    RankMark(rank: seen.before, size: 18)
                        .opacity(0.5)
                    Image(systemName: seen.climbed ? "arrow.up" : "arrow.down")
                        .font(.caption.bold())
                        .foregroundStyle(seen.climbed ? Palette.nightGreen : Color.secondary)
                }
                RankMark(rank: seen.after, size: 22)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(rankLabel(seen))
        }
        .accessibilityElement(children: .combine)
    }

    private func rankLabel(_ seen: SessionCard) -> Text {
        let after = seen.after.number ?? 0
        if seen.after == seen.before { return Text("At rank \(after)", bundle: .module) }
        return Text("From rank \(seen.before.number ?? 0) to rank \(after)", bundle: .module)
    }

    private func stat(_ value: String, _ label: Text) -> some View {
        VStack(spacing: 2) {
            Text(verbatim: value)
                .font(.title.weight(.semibold))
                .monospacedDigit()
            label
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
