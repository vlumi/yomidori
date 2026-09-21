import SwiftUI
import YomidoriCore

/// The review: the questions due now, one at a time. A tap, or a typed reading,
/// turns the card over; two answers, and the scheduler decides when it comes back.
/// No streak, no count kept against anyone; an empty queue says so.
struct ReviewView: View {
    @State private var queue: [ReviewItem] = []
    @State private var revealed = false
    @AppStorage("typedAnswers") private var typedAnswers = false
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Toggle(isOn: $typedAnswers) {
                    Label {
                        Text("Type the reading", bundle: .module)
                    } icon: {
                        Image(systemName: "keyboard")
                    }
                }
                .toggleStyle(.button)
            }
        }
        .onAppear(perform: reload)
    }

    private func review(_ item: ReviewItem) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            ReviewFront(card: item.card)
            if item.question == .meaning {
                MeaningQuestion(card: item.card)
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

    /// Before the reveal: the kana field when typing answers to a reading, else the button.
    @ViewBuilder private func prompt(_ item: ReviewItem) -> some View {
        if typedAnswers, item.question == .reading {
            TextField(text: $answer) {
                Text("Type the reading", bundle: .module)
            }
            .textFieldStyle(.roundedBorder)
            .font(.title2)
            .focused($typing)
            .submitLabel(.done)
            .onSubmit { check(item.card) }
            .onAppear { typing = true }
        } else {
            Button {
                revealed = true
            } label: {
                if item.question == .reading {
                    Text("Show the reading", bundle: .module).frame(maxWidth: .infinity)
                } else {
                    Text("Show the meaning", bundle: .module).frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    /// After the reveal: the verdict on a typed answer, the back, and the two grades,
    /// the one the verdict suggests prominent.
    @ViewBuilder private func answered(_ item: ReviewItem) -> some View {
        if let verdict {
            verdictLine(verdict)
        }
        if item.question == .reading {
            ReadingBack(card: item.card)
        } else {
            MeaningBack(card: item.card)
        }
        HStack(spacing: 16) {
            gradeButton(item, .again, prominent: verdict == false)
            gradeButton(item, .good, prominent: verdict != false)
        }
        .controlSize(.large)
    }

    private func verdictLine(_ correct: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle")
            if correct {
                Text("Correct", bundle: .module)
            } else {
                Text("Not quite. You typed \(answer).", bundle: .module)
            }
        }
        .font(.callout)
        .foregroundStyle(correct ? Palette.nightGreen : .secondary)
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

    private func check(_ card: Card) {
        verdict = ReadingCheck.matches(typed: answer, reading: card.reading)
        revealed = true
    }

    private func record(_ item: ReviewItem, _ grade: Grade) {
        var reviewed = item.card
        reviewed.setState(
            FSRS.review(item.card.state(for: item.question), grade: grade, at: Date()),
            for: item.question)
        try? Cards.store?.update(reviewed)
        revealed = false
        answer = ""
        verdict = nil
        queue.removeFirst()
    }

    private func reload() {
        queue = Cards.store?.dueItems(at: Date()) ?? []
        revealed = false
    }
}
