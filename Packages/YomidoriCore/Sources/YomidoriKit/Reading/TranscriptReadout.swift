import SwiftUI
import YomidoriCore
import YomidoriDictionary
import YomidoriMeCab

struct TranscriptReadout: View {
    enum TokenizerChoice: Hashable {
        case system
        case mecab
    }

    /// `pageOffset` is where the page on screen starts in the joined transcript, in characters.
    let transcript: String
    let stills: [Still]
    let currentTranscript: String
    let currentLines: [RecognizedLine]
    let pageOffset: Int
    @ObservedObject var selection: LiveTextSelection
    @State private var choice: TokenizerChoice = .system
    @State private var lines: [[Token]] = []
    @State private var transcriptLines = TranscriptLines("")
    @State private var selected: Token?
    @AppStorage("transcriptExpanded") private var expanded = false
    @State private var kept: Card?
    @State private var archived: [UUID: UUID] = [:]
    @AppStorage("source") private var source = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if let selected {
                wordReadout(selected)
            }
            if choice == .mecab, MeCabTokenizer.shared == nil {
                Text("MeCab could not load its dictionary.", bundle: .module)
                    .foregroundStyle(.secondary)
            }
            DisclosureGroup(isExpanded: $expanded) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(lines.indices, id: \.self) { index in
                        TokenFlow(tokens: lines[index], selected: $selected)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
            } label: {
                Text("Recognized text", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .tint(.secondary)
        }
        .task(id: "\(choice)|\(transcript)") { tokenize() }
        .task(id: "\(choice)|\(selection.text)") { showSelection() }
    }

    private var header: some View {
        HStack {
            Picker(selection: $choice) {
                Text("System", bundle: .module).tag(TokenizerChoice.system)
                Text(verbatim: "MeCab").tag(TokenizerChoice.mecab)
            } label: {
                Text("Tokenizer", bundle: .module)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 170)
            TextField(text: $source) {
                Text("Book, page", bundle: .module)
            }
            .textFieldStyle(.roundedBorder)
            .font(.callout)
            Button {
                Clipboard.copy(transcript)
            } label: {
                Label {
                    Text("Copy", bundle: .module)
                } icon: {
                    Image(systemName: "doc.on.doc")
                }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private func wordReadout(_ token: Token) -> some View {
        let dictionary = JMdict.bundled
        let entries = dictionary.map { $0.entries(for: token) } ?? []
        return WordReadout(
            token: token, entries: entries,
            accent: entries.first.flatMap { dictionary?.pitchAccent(of: $0) },
            kept: kept?.sightings.last?.surface == token.surface, canKeep: Cards.store != nil
        ) {
            keep(token, entry: entries.first)
        }
    }

    private var tokenizer: (any Tokenizer)? {
        choice == .system ? SystemTokenizer() : MeCabTokenizer.shared
    }

    private func tokenize() {
        selected = nil
        transcriptLines = TranscriptLines(transcript)
        lines = transcriptLines.lines.map { tokenizer?.tokens(in: $0) ?? [] }
    }

    /// The strip's own token on that line is preferred, so Keep knows the sentence.
    private func showSelection() {
        let text = selection.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let word = tokenizer?.tokens(in: text).first(where: \.isWord) else {
            return
        }
        if let line = lineIndex(ofSelection: selection.range),
            let match = lines[line].first(where: { $0.surface == word.surface })
        {
            selected = match
        } else {
            selected = word
        }
    }

    private func lineIndex(ofSelection range: Range<String.Index>?) -> Int? {
        guard let range, range.lowerBound <= currentTranscript.endIndex else { return nil }
        let offset =
            pageOffset
            + currentTranscript.distance(from: currentTranscript.startIndex, to: range.lowerBound)
        return transcriptLines.lineIndex(atOffset: offset, in: transcript)
    }

    private func keep(_ token: Token, entry: DictionaryEntry?) {
        let keeper = SentenceKeeper(
            transcript: transcript, transcriptLines: transcriptLines, tokenLines: lines,
            stills: stills,
            currentLines: currentLines, source: source.isEmpty ? nil : source)
        guard let store = Cards.store,
            let sighting = keeper.sighting(for: token, archived: &archived)
        else {
            return
        }
        let headword = entry?.headword ?? token.dictionaryForm ?? token.surface
        let reading = Kana.hiragana(entry?.readings.first ?? token.reading)
        kept = try? store.keep(sighting, headword: headword, reading: reading, entryID: entry?.id)
    }
}
