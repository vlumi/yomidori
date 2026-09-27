import SwiftUI
import YomidoriCore
import YomidoriDictionary

/// The questions due, shuffled, one at a time, each answered by typing or, for the pitch,
/// by a pick. A right answer counts as good at once; a wrong one shows the answer and takes
/// Again, unless the reader overrules it, or adds a meaning of their own to the card. Not
/// answering is never good.
struct ReviewView: View {
    @State private var queue: [ReviewItem] = []
    @State private var revealed = false
    @State private var answer = ""
    /// When the question now showing came up, for the time spent on it.
    @State private var shown = Date()
    @FocusState private var typing: Bool
    @AccessibilityFocusState private var verdictFocused: Bool

    var body: some View {
        Group {
            if let item = queue.first {
                review(item)
            } else {
                Text("Nothing due. Read on.", bundle: .module)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(Text("Review", bundle: .module))
        .onAppear(perform: reload)
        .onChange(of: queue.first) { shown = Date() }
    }

    private func review(_ item: ReviewItem) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            ReviewFront(card: item.card)
            switch item.question {
            case .reading: EmptyView()
            case .meaning: MeaningQuestion(card: item.card)
            case .pitch: PitchQuestion(card: item.card)
            }
            Spacer()
            if revealed {
                answered(item)
            } else {
                prompt(item)
            }
            Text(verbatim: "\(queue.count)")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityLabel(Text("\(queue.count) remaining", bundle: .module))
        }
        .padding(24)
        .tint(Palette.nightGreen)
        .onChange(of: revealed) { _, shown in
            if shown { verdictFocused = true }
        }
    }

    @ViewBuilder private func prompt(_ item: ReviewItem) -> some View {
        if item.question == .pitch {
            PitchChoices(reading: item.card.reading) { picked in
                answer = "[\(picked.downstep)]"
                settle(item, Cards.accents(of: item.card).contains(picked))
            }
        } else {
            TextField(text: $answer) {
                if item.question == .reading {
                    Text("Type the reading", bundle: .module)
                } else {
                    Text("Type the meaning", bundle: .module)
                }
            }
            .textFieldStyle(.roundedBorder)
            .font(.title2)
            .focused($typing)
            .submitLabel(.done)
            .onSubmit { check(item) }
            .onAppear { typing = true }
            Button {
                revealed = true
            } label: {
                Text("Show the answer", bundle: .module)
                    .font(.callout)
            }
            .buttonStyle(.borderless)
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
        if !answer.isEmpty {
            reconcile(item)
        }
        Button {
            record(item, .again)
        } label: {
            Text("Again", bundle: .module).frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .keyboardShortcut(.defaultAction)
        Button {
            sendToWaiting(item.card)
        } label: {
            Text("Forgot it. Back to waiting", bundle: .module)
                .font(.callout)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderless)
    }

    private var missLine: some View {
        HStack(spacing: 8) {
            Image(systemName: "xmark.circle")
                .accessibilityHidden(true)
            if answer.isEmpty {
                Text("Not answered", bundle: .module)
            } else {
                Text("Not quite. You typed \(answer).", bundle: .module)
            }
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
        .accessibilityFocused($verdictFocused)
    }

    /// Overrule a wrong verdict: a typo too broken to forgive counts as right; a meaning of
    /// the reader's own is kept on the card and counts from now on.
    private func reconcile(_ item: ReviewItem) -> some View {
        HStack(spacing: 12) {
            Button {
                record(item, .good, reconciled: true)
            } label: {
                Text("Count it right", bundle: .module)
            }
            if item.question == .meaning, !answer.trimmingCharacters(in: .whitespaces).isEmpty {
                Button {
                    record(
                        item, .good, reconciled: true,
                        accepting: answer.trimmingCharacters(in: .whitespaces))
                } label: {
                    Text("Add as an answer", bundle: .module)
                }
            }
        }
        .buttonStyle(.bordered)
        .font(.callout)
    }

    private func check(_ item: ReviewItem) {
        switch item.question {
        case .reading:
            settle(item, ReadingCheck.matches(typed: answer, reading: item.card.reading))
        case .meaning:
            settle(
                item,
                MeaningCheck.matches(
                    typed: answer, glosses: item.card.answers(glosses: glosses(of: item))))
        case .pitch:
            break
        }
    }

    private func glosses(of item: ReviewItem) -> [String] {
        JMdict.bundled?.entry(headword: item.card.headword, reading: item.card.reading)?.senses
            .flatMap(\.glosses) ?? []
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
        // Two buttons pressed at once both land here with the same item: grade it once.
        guard let current = queue.first, current.card.id == item.card.id,
            current.question == item.question
        else { return }
        let now = Date()
        let reviewed = try? Cards.store?.answer(
            item, grade: grade, at: now, reconciled: reconciled, accepting: meaning,
            glosses: meaning == nil ? [] : glosses(of: item),
            seconds: Int(now.timeIntervalSince(shown).rounded()))
        revealed = false
        answer = ""
        queue.removeFirst()
        if let reviewed {
            queue = queue.map {
                $0.card.id == reviewed.id ? ReviewItem(card: reviewed, question: $0.question) : $0
            }
        }
    }

    /// The card leaves the queue with every question it had in it, to come back through a
    /// lesson.
    private func sendToWaiting(_ card: Card) {
        var waiting = Cards.store?.card(id: card.id) ?? card
        waiting.sendToWaiting()
        try? Cards.store?.update(waiting)
        revealed = false
        answer = ""
        queue.removeAll { $0.card.id == card.id }
    }

    /// Shuffled, so a card's three questions don't follow one another unless chance says so.
    private func reload() {
        queue = Cards.dueItems(at: Date()).shuffled()
        revealed = false
    }
}
