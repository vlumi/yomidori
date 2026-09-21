import SwiftUI
import YomidoriCore
import YomidoriDictionary

struct ReadingBack: View {
    let card: Card

    var body: some View {
        let dictionary = JMdict.bundled
        let entry = dictionary?.entry(headword: card.headword, reading: card.reading)
        VStack(alignment: .leading, spacing: 8) {
            WordTitle(
                headword: card.headword, reading: card.reading,
                accent: dictionary?.pitchAccents(for: card.headword, reading: card.reading).first,
                font: .largeTitle
            ) {
                DictionaryButton(term: card.headword)
            }
            if let entry {
                MeaningFold { SensesList(entry: entry) }
            }
        }
    }
}

/// The patterns the dictionary gives, the usual one first.
struct PitchBack: View {
    let card: Card
    let accents: [PitchAccent]

    var body: some View {
        HStack(spacing: 16) {
            Text(verbatim: card.headword)
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
