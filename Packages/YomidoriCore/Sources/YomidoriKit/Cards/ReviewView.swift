import SwiftUI
import YomidoriCore
import YomidoriDictionary

/// The review: the cards due now, one at a time. The front is the sentence as it
/// stood on the page with the word marked, and the question is its reading; a tap
/// turns the card over to the reading with its pitch, the dictionary form and the
/// meaning under a fold. Two answers, and the scheduler decides when it comes back.
/// No streak, no count kept against anyone; when the queue is empty, it says so.
struct ReviewView: View {
    @State private var queue: [Card] = []
    @State private var revealed = false

    var body: some View {
        Group {
            if let card = queue.first {
                review(card)
            } else {
                Text("Nothing due. Read on.", bundle: .module)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(Text("Review", bundle: .module))
        .onAppear(perform: reload)
    }

    private func review(_ card: Card) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            front(card)
            Spacer()
            if revealed {
                back(card)
                HStack(spacing: 16) {
                    Button {
                        answer(card, .again)
                    } label: {
                        Text("Again", bundle: .module).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    Button {
                        answer(card, .good)
                    } label: {
                        Text("Good", bundle: .module).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .controlSize(.large)
            } else {
                Button {
                    revealed = true
                } label: {
                    Text("Show the reading", bundle: .module).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            Text(verbatim: "\(queue.count)")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(24)
        .tint(Palette.nightGreen)
    }

    /// The front: the latest sentence with the word marked, or the word alone when
    /// the card came from a search and has no sentence yet.
    @ViewBuilder private func front(_ card: Card) -> some View {
        if let sighting = card.sightings.max(by: { $0.date < $1.date }),
            !sighting.sentence.isEmpty
        {
            Text(marked(sighting, hidden: !revealed))
                .font(.title2)
                .textSelection(.enabled)
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
            if let entry = JMdict.bundled?.entries(matching: card.headword).first(where: {
                $0.readings.map(Kana.hiragana).contains(card.reading)
            }) {
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

    /// The sentence with the word marked in night green; on the front the word stays
    /// as it stood, since reading it is the question.
    private func marked(_ sighting: Sighting, hidden: Bool) -> AttributedString {
        var text = AttributedString(sighting.sentence)
        let count = sighting.sentence.count
        guard sighting.offset >= 0, sighting.offset + sighting.surface.count <= count else {
            return text
        }
        let start = text.index(text.startIndex, offsetByCharacters: sighting.offset)
        let end = text.index(start, offsetByCharacters: sighting.surface.count)
        text[start..<end].foregroundColor = Palette.nightGreen
        text[start..<end].font = .title2.bold()
        return text
    }

    private func answer(_ card: Card, _ grade: Grade) {
        var reviewed = card
        reviewed.review = FSRS.review(card.review, grade: grade, at: Date())
        try? Cards.store?.update(reviewed)
        revealed = false
        queue.removeFirst()
    }

    private func reload() {
        queue = Cards.store?.due(at: Date()) ?? []
        revealed = false
    }
}
