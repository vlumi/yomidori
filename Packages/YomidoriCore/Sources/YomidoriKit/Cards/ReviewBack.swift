import SwiftUI
import YomidoriCore
import YomidoriDictionary

/// The reading alone: the pitch and the meaning are questions of their own.
struct ReadingBack: View {
    let card: Card

    var body: some View {
        WordTitle(headword: card.headword, reading: card.reading, accent: nil, font: .largeTitle) {
            DictionaryButton(term: card.headword)
        }
    }
}

/// The patterns the dictionary gives, the usual one first.
struct PitchBack: View {
    let card: Card
    let accents: [PitchAccent]

    var body: some View {
        FlowLayout(spacing: 16) {
            Text(japanese: card.headword)
                .font(.title)
            ForEach(accents, id: \.downstep) { accent in
                PitchReading(reading: card.reading, accent: accent)
            }
        }
    }
}

struct MeaningBack: View {
    let card: Card

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let entry = JMdict.bundled?.entry(headword: card.headword, reading: card.reading) {
                SensesList(entry: entry)
            } else {
                Text("Not in the dictionary.", bundle: .module)
                    .foregroundStyle(.secondary)
            }
            DictionaryButton(term: card.headword)
        }
    }
}
