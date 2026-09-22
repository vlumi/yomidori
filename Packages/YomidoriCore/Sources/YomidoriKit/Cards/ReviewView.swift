import SwiftUI
import YomidoriCore
import YomidoriDictionary

/// The questions due, one at a time, each answered by typing or, for the pitch, by a pick.
/// The verdict only suggests the grade; the reader can overrule it, and add a meaning of
/// their own to the card.
struct ReviewView: View {
    @State private var queue: [ReviewItem] = []
    @State private var revealed = false
    @State private var answer = ""
    @State private var verdict: Bool?
    @FocusState private var typing: Bool

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
        }
        .padding(24)
        .tint(Palette.nightGreen)
    }

    @ViewBuilder private func prompt(_ item: ReviewItem) -> some View {
        if item.question == .pitch {
            PitchChoices(reading: item.card.reading) { picked in
                answer = "[\(picked.downstep)]"
                verdict = Cards.accents(of: item.card).contains(picked)
                revealed = true
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
                verdict = false
                revealed = true
            } label: {
                Text("Show the answer", bundle: .module)
                    .font(.callout)
            }
            .buttonStyle(.borderless)
        }
    }

    @ViewBuilder private func answered(_ item: ReviewItem) -> some View {
        if let verdict {
            verdictLine(verdict)
        }
        switch item.question {
        case .reading: ReadingBack(card: item.card)
        case .meaning: MeaningBack(card: item.card)
        case .pitch: PitchBack(card: item.card, accents: Cards.accents(of: item.card))
        }
        if verdict == false {
            reconcile(item)
        }
        HStack(spacing: 16) {
            gradeButton(item, .again, prominent: verdict == false)
            gradeButton(item, .good, prominent: verdict != false)
        }
        .controlSize(.large)
        Button {
            sendToWaiting(item.card)
        } label: {
            Text("Forgot it. Back to waiting", bundle: .module)
                .font(.callout)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderless)
    }

    private func verdictLine(_ correct: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle")
            if correct {
                Text("Correct", bundle: .module)
            } else if answer.isEmpty {
                Text("Not answered", bundle: .module)
            } else {
                Text("Not quite. You typed \(answer).", bundle: .module)
            }
        }
        .font(.callout)
        .foregroundStyle(correct ? Palette.nightGreen : .secondary)
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
                    var card = item.card
                    card.acceptedMeanings.append(answer.trimmingCharacters(in: .whitespaces))
                    record(item, .good, reconciled: true, card: card)
                } label: {
                    Text("Add as an answer", bundle: .module)
                }
            }
        }
        .buttonStyle(.bordered)
        .font(.callout)
    }

    @ViewBuilder private func gradeButton(_ item: ReviewItem, _ grade: Grade, prominent: Bool)
        -> some View
    {
        let label = Text(grade == .again ? "Again" : "Good", bundle: .module).frame(
            maxWidth: .infinity)
        if prominent {
            Button {
                record(item, grade)
            } label: {
                label
            }.buttonStyle(.borderedProminent)
        } else {
            Button {
                record(item, grade)
            } label: {
                label
            }.buttonStyle(.bordered)
        }
    }

    private func check(_ item: ReviewItem) {
        switch item.question {
        case .reading:
            verdict = ReadingCheck.matches(typed: answer, reading: item.card.reading)
        case .meaning:
            let entry = JMdict.bundled?.entry(
                headword: item.card.headword, reading: item.card.reading)
            verdict = MeaningCheck.matches(
                typed: answer, glosses: entry?.senses.flatMap(\.glosses) ?? [],
                accepted: item.card.acceptedMeanings)
        case .pitch:
            verdict = nil
        }
        revealed = true
    }

    private func record(
        _ item: ReviewItem, _ grade: Grade, reconciled: Bool = false, card: Card? = nil
    ) {
        var reviewed = card ?? item.card
        reviewed.answer(item.question, grade: grade, at: Date(), reconciled: reconciled)
        try? Cards.store?.update(reviewed)
        revealed = false
        answer = ""
        verdict = nil
        queue.removeFirst()
    }

    /// The card leaves the queue with every question it had in it, to come back through a
    /// lesson.
    private func sendToWaiting(_ card: Card) {
        var waiting = card
        waiting.sendToWaiting()
        try? Cards.store?.update(waiting)
        revealed = false
        answer = ""
        verdict = nil
        queue.removeAll { $0.card.id == card.id }
    }

    private func reload() {
        queue = Cards.dueItems(at: Date())
        revealed = false
    }
}
