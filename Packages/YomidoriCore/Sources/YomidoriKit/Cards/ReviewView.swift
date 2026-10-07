import SwiftUI
import YomidoriCore
import YomidoriDictionary

/// The questions due, shuffled, one at a time, each answered by typing or, for the pitch,
/// by a pick. A right answer counts as good at once; a wrong one shows the answer and takes
/// Again, unless the reader overrules it, or adds a meaning of their own to the card. Not
/// answering is never good.
struct ReviewView: View {
    /// A drill over these cards only, as after a lesson: a miss comes back a few questions on,
    /// and the drill is over when every question has been answered right. Nil for a review.
    var practicing: Set<UUID>?
    @State private var queue = ReviewQueue([])
    @AppStorage(SettingsKey.retention) private var retention = FSRS.desiredRetention
    /// Loaded once; coming back to the screen mustn't start it over and lose the misses
    /// still to be put right.
    @State private var loaded = false
    @State private var revealed = false
    @State private var answer = ""
    /// What was typed, or nil for nothing but spaces: one rule for every button and line.
    private var typed: String? {
        let trimmed = answer.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }
    /// When the question now showing came up, for the time spent on it.
    @State private var shown = Date()
    /// The sentence each question shows, by `key`.
    @State private var picked: [String: UUID] = [:]
    /// The sentence being corrected, over the question.
    @State private var editing: Sighting?
    /// This sitting's answers, for the summary at its end.
    @State private var session = DayTally(day: Date())
    @AccessibilityFocusState private var verdictFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if let item = queue.current {
                review(item)
            } else if session.total > 0 {
                SessionSummary(session: session) { dismiss() }
            } else {
                Text("Nothing due. Read on.", bundle: .module)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(
            practicing == nil ? Text("Review", bundle: .module) : Text("Practice", bundle: .module)
        )
        // A small title in the bar; the question's name and what remains stand down by the
        // answer, where the eyes are.
        .navigationBarTitleDisplayModeInline()
        .onAppear(perform: reload)
        .onChange(of: queue.current) { shown = Date() }
    }

    /// The question's tag, a word when it is a repeat, and how many remain.
    private func tagRow(_ item: ReviewItem) -> some View {
        HStack(spacing: 8) {
            QuestionTag(question: item.question)
            if practicing == nil, queue.isRepeat(item) {
                // A repeat, said in a word beside the tag rather than a banner over the
                // word that pushed it down the page.
                Label {
                    Text("Once more", bundle: .module)
                } icon: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                .accessibilityLabel(
                    Text(
                        "Once more, to get it right. This one no longer counts.",
                        bundle: .module))
            }
            Spacer()
            Text("\(queue.count) remaining", bundle: .module)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    /// The question scrolls, so a long sentence shows whole; the answer stays put below.
    private func review(_ item: ReviewItem) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ReviewFront(
                        card: item.card, sightingID: picked[Self.key(item)],
                        showsForm: item.question == .reading
                    ) { editing = $0 }
                    switch item.question {
                    case .reading: EmptyView()
                    case .meaning: MeaningQuestion(card: item.card)
                    case .pitch: PitchQuestion(card: item.card)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
            // Which question this is and how many remain, right above the answer.
            tagRow(item)
            if revealed {
                answered(item)
            } else {
                prompt(item)
            }
        }
        .padding(24)
        .tint(Palette.nightGreen)
        .onChange(of: revealed) { _, shown in
            if shown { verdictFocused = true }
        }
        .sheet(item: $editing) { sighting in
            SentenceEditor(sighting: sighting) { replace($0, on: item.card) }
                .sheetSize(width: 520, height: 360)
        }
        .readingWidth()
    }

    /// The corrected sentence goes on the card at once, and on to the questions still queued.
    private func replace(_ sighting: Sighting, on card: Card) {
        var changed = Cards.store?.card(id: card.id) ?? card
        changed.replace(sighting)
        Cards.write { try Cards.store?.update(changed) }
        queue.replace(card: changed)
    }

    @ViewBuilder private func prompt(_ item: ReviewItem) -> some View {
        if item.question == .pitch {
            PitchChoices(reading: item.card.reading) { picked in
                answer = "[\(picked.downstep)]"
                settle(item, Cards.accents(of: item.card).contains(picked))
            }
        } else {
            AnswerField(
                text: $answer,
                placeholder: item.question == .reading
                    ? String(localized: "Type the reading", bundle: .module)
                    : String(localized: "Type the meaning", bundle: .module),
                context: "answer.\(item.question.rawValue)",
                asciiOnly: item.question == .meaning,
                question: AnyHashable("\(item.card.id) \(item.question.rawValue)")
            ) { check(item) }
            .id(item.question)
            // The confirming action on the right, as everywhere on iOS and the Mac.
            HStack(spacing: 12) {
                // What is typed is checked first: a right answer is right, whichever button.
                Button {
                    if typed == nil {
                        revealed = true
                    } else {
                        check(item)
                    }
                } label: {
                    FittingLabel(title: Text("Show the answer", bundle: .module), symbol: "eye")
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.return, modifiers: .command)
                .help(Text("Show the answer (⌘↩)", bundle: .module))
                Button {
                    check(item)
                } label: {
                    FittingLabel(title: Text("Check", bundle: .module), symbol: "checkmark.circle")
                }
                .buttonStyle(.borderedProminent)
                .disabled(typed == nil)
            }
            .controlSize(.large)
        }
    }

    /// The answer shown after a miss: only the part asked, so a reading missed is not also
    /// the meaning given away.
    @ViewBuilder private func answered(_ item: ReviewItem) -> some View {
        missLine
        switch item.question {
        case .reading: ReadingBack(card: item.card)
        case .meaning: MeaningBack(card: item.card)
        case .pitch: PitchBack(card: item.card, accents: Cards.accents(of: item.card))
        }
        VStack(spacing: 12) {
            Button {
                record(item, .again)
            } label: {
                Label {
                    Text("Again", bundle: .module)
                } icon: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            if typed != nil {
                reconcile(item)
            }
            Button {
                sendToWaiting(item.card)
            } label: {
                Label {
                    Text("Forgot it. Back to waiting", bundle: .module)
                } icon: {
                    Image(systemName: "tray.and.arrow.down")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.delete, modifiers: .command)
            .help(Text("Back to waiting (⌘⌫)", bundle: .module))
        }
        .controlSize(.large)
    }

    private var missLine: some View {
        HStack(spacing: 8) {
            Image(systemName: "xmark.circle")
                .accessibilityHidden(true)
            if let typed {
                Text("Not quite. You typed \(typed).", bundle: .module)
            } else {
                Text("Not answered", bundle: .module)
            }
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
        .accessibilityFocused($verdictFocused)
    }

    private func check(_ item: ReviewItem) {
        switch item.question {
        case .reading:
            settle(item, ReadingCheck.matches(typed: answer, reading: item.card.reading))
        case .meaning:
            settle(
                item,
                MeaningCheck.matches(
                    typed: answer, glosses: item.card.answers(glosses: Self.glosses(of: item))))
        case .pitch:
            break
        }
    }

    /// Right is good, and the next question comes at once; wrong shows the answer.
    private func settle(_ item: ReviewItem, _ correct: Bool) {
        if correct {
            record(item, .good)
        } else {
            revealed = true
        }
    }

    private func record(
        _ item: ReviewItem, _ grade: Grade, reconciled: Bool = false,
        accepting meaning: String? = nil
    ) {
        guard queue.isCurrent(item) else { return }
        let now = Date()
        let seconds = Int(now.timeIntervalSince(shown).rounded())
        let reviewed: Card?
        if queue.isRepeat(item), practicing == nil {
            // Once more, to finish right: nothing on the schedule, the log or the summary;
            // a meaning of the reader's own is still kept.
            reviewed = meaning.flatMap { Self.keep($0, on: item) }
        } else {
            reviewed = Cards.write {
                try Cards.store?.answer(
                    item, grade: grade, at: now, reconciled: reconciled, accepting: meaning,
                    glosses: meaning == nil ? [] : Self.glosses(of: item), seconds: seconds,
                    retention: retention)
            }.flatMap { $0 }
            session.answered[item.question, default: 0] += 1
            if grade == .good { session.right[item.question, default: 0] += 1 }
            session.seconds += min(max(seconds, 0), ReviewEntry.longestCounted)
        }
        revealed = false
        answer = ""
        queue.answered(item, grade: grade, card: reviewed)
    }

    /// The card leaves the queue with every question it had in it, to come back through a
    /// lesson.
    private func sendToWaiting(_ card: Card) {
        var waiting = Cards.store?.card(id: card.id) ?? card
        waiting.sendToWaiting()
        Cards.write { try Cards.store?.update(waiting) }
        revealed = false
        answer = ""
        queue.remove(card: card.id)
    }

    /// Shuffled, so a card's three questions don't follow one another unless chance says so.
    /// One of each card's sentences, at random, for each question; picked once, so the
    /// sentence doesn't change while the question is up.
    private func reload() {
        guard !loaded else { return }
        loaded = true
        if let practicing {
            queue = ReviewQueue(
                Cards.dueItems(at: Date()).filter { practicing.contains($0.card.id) }.shuffled())
        } else {
            queue = ReviewQueue(Cards.dueItems(at: Date()).shuffled())
        }
        picked = Dictionary(
            queue.items.compactMap { item in
                item.card.sightingsWithSentence.randomElement().map { (Self.key(item), $0.id) }
            }, uniquingKeysWith: { first, _ in first })
        revealed = false
    }

    private static func key(_ item: ReviewItem) -> String {
        "\(item.card.id.uuidString) \(item.question.rawValue)"
    }
}

/// A button's title with its icon, the icon dropped when the two don't fit on one line.
private struct FittingLabel: View {
    let title: Text
    let symbol: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            Label {
                title
            } icon: {
                Image(systemName: symbol)
            }
            .lineLimit(1)
            title.lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

extension ReviewView {
    /// Overrule a wrong verdict: a typo too broken to forgive counts as right; a meaning of
    /// the reader's own is kept on the card and counts from now on.
    private func reconcile(_ item: ReviewItem) -> some View {
        HStack(spacing: 12) {
            Button {
                record(item, .good, reconciled: true)
            } label: {
                Label {
                    Text("Count it right", bundle: .module)
                } icon: {
                    Image(systemName: "checkmark")
                }
                .frame(maxWidth: .infinity)
            }
            .keyboardShortcut("y", modifiers: .command)
            .help(Text("Count it right (⌘Y)", bundle: .module))
            if item.question == .meaning, let typed {
                Button {
                    record(
                        item, .good, reconciled: true,
                        accepting: typed)
                } label: {
                    Label {
                        Text("Add as an answer", bundle: .module)
                    } icon: {
                        Image(systemName: "plus.circle")
                    }
                    .frame(maxWidth: .infinity)
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])
                .help(Text("Add as an answer (⌘⇧A)", bundle: .module))
            }
        }
        .buttonStyle(.bordered)
    }
}
