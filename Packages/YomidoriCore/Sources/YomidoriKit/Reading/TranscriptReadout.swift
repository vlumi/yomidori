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
    @State private var words: [FoundWord] = []
    @State private var keptSurfaces: Set<String> = []
    @AppStorage("transcriptExpanded") private var expanded = false
    @State private var archived: [UUID: UUID] = [:]
    @AppStorage("source") private var source = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            ForEach(words.indices, id: \.self) { index in
                if index > 0 {
                    Divider()
                }
                wordReadout(words[index])
            }
            if choice == .mecab, MeCabTokenizer.shared == nil {
                Text("MeCab could not load its dictionary.", bundle: .module)
                    .foregroundStyle(.secondary)
            }
            DisclosureGroup(isExpanded: $expanded) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(lines.indices, id: \.self) { index in
                        TokenFlow(tokens: lines[index], selected: words.first?.first) { token in
                            words = WordFinder.words(in: [token], dictionary: JMdict.bundled)
                        }
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

    private func wordReadout(_ word: FoundWord) -> some View {
        WordReadout(
            word: word, accent: word.entries.first.flatMap { JMdict.bundled?.pitchAccent(of: $0) },
            kept: keptSurfaces.contains(word.surface), canKeep: Cards.store != nil
        ) {
            keep(word)
        }
    }

    private var tokenizer: (any Tokenizer)? {
        choice == .system ? SystemTokenizer() : MeCabTokenizer.shared
    }

    private func tokenize() {
        words = []
        keptSurfaces = []
        transcriptLines = TranscriptLines(transcript)
        lines = transcriptLines.lines.map { tokenizer?.tokens(in: $0) ?? [] }
    }

    /// The strip's own tokens on that line are preferred, so Keep knows the sentence.
    private func showSelection() {
        let text = selection.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let tokens = tokenizer?.tokens(in: text) else { return }
        let found = WordFinder.words(in: tokens, dictionary: JMdict.bundled)
        if let line = lineIndex(ofSelection: selection.range) {
            words = found.map { $0.aligned(to: lines[line]) ?? $0 }
        } else {
            words = found
        }
    }

    private func lineIndex(ofSelection range: Range<String.Index>?) -> Int? {
        guard let range, range.lowerBound <= currentTranscript.endIndex else { return nil }
        let offset =
            pageOffset
            + currentTranscript.distance(from: currentTranscript.startIndex, to: range.lowerBound)
        return transcriptLines.lineIndex(atOffset: offset, in: transcript)
    }

    private func keep(_ word: FoundWord) {
        let keeper = SentenceKeeper(
            transcript: transcript, transcriptLines: transcriptLines, tokenLines: lines,
            stills: stills,
            currentLines: currentLines, source: source.isEmpty ? nil : source)
        guard let store = Cards.store,
            let sighting = keeper.sighting(for: word, archived: &archived)
        else {
            return
        }
        let entry = word.entries.first
        let headword = entry?.headword ?? word.dictionaryForm ?? word.surface
        let reading = Kana.hiragana(entry?.readings.first ?? word.reading)
        guard
            (try? store.keep(sighting, headword: headword, reading: reading, entryID: entry?.id))
                != nil
        else { return }
        keptSurfaces.insert(word.surface)
    }
}
