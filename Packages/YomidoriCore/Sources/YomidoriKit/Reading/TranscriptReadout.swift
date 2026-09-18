import SwiftUI
import YomidoriCore
import YomidoriDictionary
import YomidoriMeCab

/// The Live Text transcript as its words: a line per line of the page, each word
/// with its reading, a tap showing the word large with its reading and dictionary
/// form. A switch runs the same page through the OS's analyzer or through MeCab,
/// so the two tokenizers are compared on real pages; the transcript copies out.
struct TranscriptReadout: View {
    enum Choice: Hashable {
        case system
        case mecab
    }

    let transcript: String
    let still: Still?
    @State private var choice: Choice = .system
    @State private var lines: [[Token]] = []
    @State private var selected: Token?
    @State private var kept: Card?
    @State private var stillID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Picker(selection: $choice) {
                    Text("System", bundle: .module).tag(Choice.system)
                    Text(verbatim: "MeCab").tag(Choice.mecab)
                } label: {
                    Text("Tokenizer", bundle: .module)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
                Spacer()
                Button {
                    Clipboard.copy(transcript)
                } label: {
                    Label {
                        Text("Copy", bundle: .module)
                    } icon: {
                        Image(systemName: "doc.on.doc")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            if let selected {
                word(selected)
            }
            if choice == .mecab, MeCabTokenizer.shared == nil {
                Text("MeCab could not load its dictionary.", bundle: .module)
                    .foregroundStyle(.secondary)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(lines.indices, id: \.self) { index in
                        TokenFlow(tokens: lines[index], selected: $selected)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 240)
        }
        .task(id: "\(choice)|\(transcript)") { tokenize() }
    }

    /// The tapped word, large: its reading with its pitch drawn over it where the
    /// dictionary knows the word, its dictionary form when known, and the meaning
    /// folded under it, since the reading is what was asked for.
    private func word(_ token: Token) -> some View {
        let dictionary = JMdict.bundled
        let entries = dictionary.map { matches(for: token, in: $0) } ?? []
        let accent = dictionary.flatMap { dictionary -> PitchAccent? in
            guard let entry = entries.first, let reading = entry.readings.first else { return nil }
            return dictionary.pitchAccents(for: entry.headword, reading: reading).first
        }
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(verbatim: token.surface)
                    .font(.title)
                if let accent, let reading = entries.first?.readings.first {
                    PitchReading(reading: Kana.hiragana(reading), accent: accent)
                } else {
                    Text(verbatim: token.reading)
                        .font(.title3)
                        .foregroundStyle(Palette.nightGreen)
                }
                if let form = token.dictionaryForm {
                    Text(verbatim: form)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                keepButton(token, entry: entries.first)
            }
            .textSelection(.enabled)
            if dictionary != nil {
                DisclosureGroup {
                    meaning(entries)
                } label: {
                    Text("Meaning", bundle: .module)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tint(.secondary)
            }
        }
    }

    /// Keep the word as a card, with the line it stands in as the sentence and the
    /// still it was read from; a word already kept says so.
    @ViewBuilder private func keepButton(_ token: Token, entry: DictionaryEntry?) -> some View {
        if let kept, kept.sightings.last?.surface == token.surface {
            Label {
                Text("Kept", bundle: .module)
            } icon: {
                Image(systemName: "checkmark")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        } else if Cards.store != nil {
            Button {
                keep(token, entry: entry)
            } label: {
                Label {
                    Text("Keep", bundle: .module)
                } icon: {
                    Image(systemName: "plus.rectangle.on.rectangle")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private func keep(_ token: Token, entry: DictionaryEntry?) {
        guard let store = Cards.store,
            let lineIndex = lines.firstIndex(where: { $0.contains(token) })
        else { return }
        let line = String(
            transcript.split(separator: "\n", omittingEmptySubsequences: true)[lineIndex])
        if stillID == nil, let still {
            stillID = try? StillArchive.save(still)
        }
        let sighting = Sighting(
            sentence: line, surface: token.surface,
            offset: line.distance(from: line.startIndex, to: token.range.lowerBound),
            stillID: stillID, source: nil, date: Date())
        let headword = entry?.headword ?? token.dictionaryForm ?? token.surface
        let reading = Kana.hiragana(entry?.readings.first ?? token.reading)
        kept = try? store.keep(sighting, headword: headword, reading: reading, entryID: entry?.id)
    }

    /// The word's entries: the tokenizer's dictionary form first, then the word as it
    /// stands and the forms its stem can be deinflected to, then its reading. A word
    /// with no entry is either rare or misread.
    private func matches(for token: Token, in dictionary: some WordDictionary) -> [DictionaryEntry]
    {
        let candidates =
            [token.dictionaryForm].compactMap { $0 } + Deinflector.candidates(for: token.surface)
            + [token.reading]
        return candidates.lazy.map(dictionary.entries(matching:)).first { !$0.isEmpty } ?? []
    }

    private func meaning(_ entries: [DictionaryEntry]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if entries.isEmpty {
                Text("Not in the dictionary.", bundle: .module)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ForEach(entries.prefix(3)) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: "\(entry.headword)  \(entry.readings.joined(separator: "、"))")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    ForEach(entry.senses.prefix(4).indices, id: \.self) { index in
                        Text(
                            verbatim:
                                "\(index + 1). \(entry.senses[index].glosses.joined(separator: "; "))"
                        )
                        .font(.callout)
                    }
                }
            }
        }
        .textSelection(.enabled)
        .padding(.top, 2)
    }

    /// The transcript's lines through the chosen tokenizer; a page's lines stay lines.
    private func tokenize() {
        selected = nil
        let tokenizer: (any Tokenizer)? =
            choice == .system ? SystemTokenizer() : MeCabTokenizer.shared
        lines = transcript.split(separator: "\n", omittingEmptySubsequences: true)
            .map { tokenizer?.tokens(in: String($0)) ?? [] }
    }
}
