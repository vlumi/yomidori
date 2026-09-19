import SwiftUI
import YomidoriCore
import YomidoriDictionary

/// The review: the cards due now, one at a time. The front is the sentence as it
/// stood on the page with the word marked, and the question is its reading; a tap
/// turns the card over to the reading with its pitch, the dictionary form and the
/// meaning under a fold. Two answers, and the scheduler decides when it comes back.
/// No streak, no count kept against anyone; when the queue is empty, it says so.
struct ReviewView: View {
    @State private var queue: [ReviewItem] = []
    @State private var revealed = false
    /// Typed answers: the reading typed in kana and checked strictly, every review a
    /// few words of kana typing on vocabulary actually met. Remembered.
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
        let card = item.card
        return VStack(alignment: .leading, spacing: 20) {
            front(card)
            if item.question == .meaning {
                askedMeaning(card)
            }
            Spacer()
            if revealed {
                if let verdict {
                    verdictLine(verdict)
                }
                if item.question == .reading {
                    back(card)
                } else {
                    meaningBack(card)
                }
                HStack(spacing: 16) {
                    gradeButton(item, .again, prominent: verdict == false)
                    gradeButton(item, .good, prominent: verdict != false)
                }
                .controlSize(.large)
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
        let card = item.card
        if typedAnswers, item.question == .reading {
            TextField(text: $answer) {
                Text("Type the reading", bundle: .module)
            }
            .textFieldStyle(.roundedBorder)
            .font(.title2)
            .focused($typing)
            .submitLabel(.done)
            .onSubmit { check(card) }
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

    /// The front: the latest sentence with the word marked, or the word alone when
    /// the card came from a search and has no sentence yet.
    @ViewBuilder private func front(_ card: Card) -> some View {
        if let sighting = card.sightings.max(by: { $0.date < $1.date }),
            !sighting.sentence.isEmpty
        {
            MarkedSentence(sighting: sighting, font: .title2)
            if let cropID = sighting.cropID, let image = StillArchive.load(cropID) {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            if let source = sighting.source {
                Text(verbatim: source)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            Text(verbatim: card.headword)
                .font(.largeTitle)
                .foregroundStyle(Palette.nightGreen)
        }
    }

    /// Whether the typed reading was the card's; the wrong one is shown as typed.
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
                answer(item, grade)
            } label: {
                label
            }.buttonStyle(.borderedProminent)
        } else {
            Button {
                answer(item, grade)
            } label: {
                label
            }.buttonStyle(.bordered)
        }
    }

    /// A meaning question gives the reading away; the question is what the word means.
    private func askedMeaning(_ card: Card) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(verbatim: card.headword)
                .font(.title)
            Text(verbatim: card.reading)
                .font(.title3)
                .foregroundStyle(Palette.nightGreen)
            Text("What does it mean?", bundle: .module)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    /// The meaning's back: the senses, and the system dictionary.
    private func meaningBack(_ card: Card) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let entry = dictionaryEntry(card) {
                ForEach(entry.senses.prefix(4).indices, id: \.self) { index in
                    Text(
                        verbatim:
                            "\(index + 1). \(entry.senses[index].glosses.joined(separator: "; "))"
                    )
                    .font(.callout)
                }
            } else {
                Text("Not in the dictionary.", bundle: .module)
                    .foregroundStyle(.secondary)
            }
            DictionaryButton(term: card.headword)
        }
    }

    private func dictionaryEntry(_ card: Card) -> DictionaryEntry? {
        JMdict.bundled?.entry(headword: card.headword, reading: card.reading)
    }

    private func check(_ card: Card) {
        verdict = ReadingCheck.matches(typed: answer, reading: card.reading)
        revealed = true
    }

    private func back(_ card: Card) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(verbatim: card.headword)
                    .font(.largeTitle)
                if let accent = JMdict.bundled?.pitchAccents(
                    for: card.headword, reading: card.reading
                ).first {
                    PitchReading(reading: card.reading, accent: accent)
                } else {
                    Text(verbatim: card.reading)
                        .font(.title2)
                        .foregroundStyle(Palette.nightGreen)
                }
                Spacer()
                DictionaryButton(term: card.headword)
            }
            .textSelection(.enabled)
            if let entry = dictionaryEntry(card) {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(entry.senses.prefix(4).indices, id: \.self) { index in
                            Text(
                                verbatim:
                                    "\(index + 1). \(entry.senses[index].glosses.joined(separator: "; "))"
                            )
                            .font(.callout)
                        }
                    }
                    .padding(.top, 2)
                } label: {
                    Text("Meaning", bundle: .module)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tint(.secondary)
            }
        }
    }

    private func answer(_ item: ReviewItem, _ grade: Grade) {
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
