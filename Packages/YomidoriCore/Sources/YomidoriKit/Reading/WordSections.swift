import SwiftUI
import YomidoriCore

/// The sections under a word's title, on the entry screen and on its card alike: every
/// reading with its pitch, the senses, the kanji, the words read the same way, the words
/// it appears in.
struct WordSections: View {
    let headword: String
    let details: WordDetails

    var body: some View {
        if let entry = details.entry {
            readings(entry)
            senses(entry)
        }
        if !details.kanji.isEmpty {
            Section {
                ForEach(details.kanji, id: \.literal) { kanji in
                    NavigationLink(value: kanji) { KanjiRow(kanji: kanji) }
                }
            } header: {
                Text("Kanji", bundle: .module)
            }
        }
        if !details.homophones.isEmpty {
            entries(details.homophones, header: Text("Same reading", bundle: .module))
        }
        if !details.containing.isEmpty {
            entries(details.containing, header: Text("Words with \(headword)", bundle: .module))
        }
    }

    private func readings(_ entry: DictionaryEntry) -> some View {
        Section {
            ForEach(entry.readings, id: \.self) { reading in
                let kana = Kana.hiragana(reading)
                HStack(spacing: 10) {
                    if let accents = details.accents[kana], !accents.isEmpty {
                        ForEach(accents.indices, id: \.self) { index in
                            PitchReading(reading: kana, accent: accents[index])
                        }
                    } else {
                        Text(verbatim: kana)
                            .font(.title3)
                            .foregroundStyle(Palette.nightGreen)
                    }
                }
            }
            if entry.kanji.count > 1 {
                Text(verbatim: entry.kanji.dropFirst().joined(separator: "、"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Readings", bundle: .module)
        }
    }

    private func senses(_ entry: DictionaryEntry) -> some View {
        Section {
            ForEach(entry.senses.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: entry.senses[index].partsOfSpeech.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(
                        verbatim:
                            "\(index + 1). \(entry.senses[index].glosses.joined(separator: "; "))"
                    )
                }
            }
        } header: {
            Text("Meaning", bundle: .module)
        }
    }

    private func entries(_ entries: [DictionaryEntry], header: Text) -> some View {
        Section {
            ForEach(entries) { entry in
                NavigationLink(value: entry) {
                    EntryRow(entry: entry, accent: details.accent(ofEntry: entry))
                }
            }
        } header: {
            header
        }
    }
}
