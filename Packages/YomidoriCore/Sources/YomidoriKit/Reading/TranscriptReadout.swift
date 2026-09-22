import SwiftUI
import YomidoriCore
import YomidoriDictionary
import YomidoriMeCab

struct TranscriptReadout: View {
    /// `pageOffset` is where the page on screen starts in the joined transcript, in characters.
    let transcript: String
    let stills: [Still]
    let currentTranscript: String
    let currentLines: [RecognizedLine]
    let pageOffset: Int
    @ObservedObject var selection: LiveTextSelection
    @AppStorage(TokenizerChoice.key) private var choice: TokenizerChoice = .system
    @State private var lines: [[Token]] = []
    @State private var transcriptLines = TranscriptLines("")
    @State private var words: [FoundWord] = []
    @State private var keptSurfaces: Set<String> = []
    @AppStorage("transcriptExpanded") private var expanded = false
    @State private var archived: [UUID: UUID] = [:]
    @AppStorage("keepsPhotos") private var keepsPhotos = false

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
            CollectionPicker()
                .controlSize(.small)
            Spacer()
            tokenizerMenu
            Toggle(isOn: $keepsPhotos) {
                Label {
                    Text("Keep the photo too", bundle: .module)
                } icon: {
                    Image(systemName: keepsPhotos ? "photo.fill" : "photo")
                }
            }
            .toggleStyle(.button)
            .labelStyle(.iconOnly)
            .controlSize(.small)
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

    /// The analyzer, switched right here so the same page can be cut both ways.
    private var tokenizerMenu: some View {
        Menu {
            Picker(selection: $choice) {
                Text("System", bundle: .module).tag(TokenizerChoice.system)
                Text(verbatim: "MeCab").tag(TokenizerChoice.mecab)
            } label: {
                Text("Tokenizer", bundle: .module)
            }
        } label: {
            Label {
                Text(choice == .system ? "System" : "MeCab", bundle: .module)
            } icon: {
                Image(systemName: "text.word.spacing")
            }
            .font(.caption)
        }
        .controlSize(.small)
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
        choice.tokenizer
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
        if let line = transcriptLines.lineIndex(
            ofSelection: selection.range, in: currentTranscript, pageOffset: pageOffset,
            transcript: transcript)
        {
            words = found.map { $0.aligned(to: lines[line]) ?? $0 }
        } else {
            words = found
        }
        for entry in words.compactMap(\.entries.first) {
            Cards.noteLookup(of: entry, from: .page)
        }
    }

    private func keep(_ word: FoundWord) {
        let keeper = SentenceKeeper(
            transcript: transcript, transcriptLines: transcriptLines, tokenLines: lines,
            stills: stills,
            currentLines: currentLines, source: nil, keepsImages: keepsPhotos)
        guard let store = Cards.store,
            let sighting = keeper.sighting(for: word, archived: &archived)
        else {
            return
        }
        let entry = word.entries.first
        let headword = entry?.headword ?? word.dictionaryForm ?? word.surface
        let reading = Kana.hiragana(entry?.readings.first ?? word.reading)
        guard
            (try? store.keep(
                sighting, headword: headword, reading: reading, entryID: entry?.id,
                collection: Cards.currentCollectionID())) != nil
        else { return }
        keptSurfaces.insert(word.surface)
    }
}
