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
            QuestionTag(question: item.question)
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
            AnswerField(
                text: $answer,
                placeholder: item.question == .reading
                    ? String(localized: "Type the reading", bundle: .module)
                    : String(localized: "Type the meaning", bundle: .module),
                context: "answer.\(item.question.rawValue)",
                asciiOnly: item.question == .meaning
            ) { check(item) }
            .id(item.question)
            HStack(spacing: 12) {
                Button {
                    check(item)
                } label: {
                    Label {
                        Text("Check", bundle: .module)
                    } icon: {
                        Image(systemName: "checkmark.circle")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(answer.trimmingCharacters(in: .whitespaces).isEmpty)
                // What is typed is checked first: a right answer is right, whichever button.
                Button {
                    if answer.trimmingCharacters(in: .whitespaces).isEmpty {
                        revealed = true
                    } else {
                        check(item)
                    }
                } label: {
                    Label {
                        Text("Show the answer", bundle: .module)
                    } icon: {
                        Image(systemName: "eye")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
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
            if !answer.isEmpty {
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
        }
        .controlSize(.large)
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
                Label {
                    Text("Count it right", bundle: .module)
                } icon: {
                    Image(systemName: "checkmark")
                }
                .frame(maxWidth: .infinity)
            }
            if item.question == .meaning, !answer.trimmingCharacters(in: .whitespaces).isEmpty {
                Button {
                    record(
                        item, .good, reconciled: true,
                        accepting: answer.trimmingCharacters(in: .whitespaces))
                } label: {
                    Label {
                        Text("Add as an answer", bundle: .module)
                    } icon: {
                        Image(systemName: "plus.circle")
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .buttonStyle(.bordered)
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
