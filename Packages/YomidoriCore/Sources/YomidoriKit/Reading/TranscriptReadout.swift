import SwiftUI
import YomidoriCore
import YomidoriDictionary
import YomidoriMeCab

struct TranscriptReadout: View {
    let transcript: String
    let currentTranscript: String
    /// Where the page on screen starts in the joined transcript, in characters.
    let pageOffset: Int
    @ObservedObject var selection: LiveTextSelection
    @AppStorage(TokenizerChoice.key) private var choice: TokenizerChoice = .system
    @State private var lines: [[Token]] = []
    /// The reader's corrections to the transcript, cleared with a new page.
    @State private var fixes: [TextFix] = []
    /// After a fix, the stretch of a line whose words are found again.
    @State private var refind: (line: Int, range: Range<Int>)?
    @State private var transcriptLines = TranscriptLines("")
    @State private var words: [FoundWord] = []
    @State private var currentLookup: UUID?
    @State private var keptSurfaces: Set<String> = []
    @AppStorage(SettingsKey.transcriptExpanded) private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if selection.looking {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Looking it up…", bundle: .module)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
            } else {
                ForEach(words.indices, id: \.self) { index in
                    if index > 0 {
                        Divider()
                    }
                    wordReadout(words[index])
                }
            }
            if choice == .mecab, MeCabTokenizer.shared == nil {
                Text("MeCab could not load its dictionary.", bundle: .module)
                    .foregroundStyle(.secondary)
            }
            DisclosureGroup(isExpanded: $expanded) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(lines.indices, id: \.self) { index in
                        TokenFlow(tokens: lines[index], selected: words.first?.first) { token in
                            guard !selection.looking else { return }
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
        .task(id: "\(choice)|\(fixed)") { tokenize() }
        .onChange(of: transcript) { fixes = [] }
        .task(id: "\(choice)|\(selection.text)") { await showSelection() }
    }

    private var header: some View {
        HStack {
            CollectionPicker()
                .controlSize(.small)
            Spacer()
            tokenizerMenu
            Button {
                Clipboard.copy(fixed)
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
        .accessibilityLabel(Text("Tokenizer", bundle: .module))
        .accessibilityValue(Text(choice == .system ? "System" : "MeCab", bundle: .module))
    }

    private func wordReadout(_ word: FoundWord) -> some View {
        let line = lines.firstIndex { $0.contains(word.first) }
        return WordReadout(
            word: word, accent: word.entries.first.flatMap { JMdict.bundled?.pitchAccent(of: $0) },
            kept: keptSurfaces.contains(word.surface), canKeep: Cards.store != nil,
            fix: line.map { line in
                { index, replacement in fix(word, onLine: line, index, replacement) }
            }
        ) {
            keep(word)
        }
    }

    /// The transcript as recognized, with the reader's corrections in.
    private var fixed: String {
        TextFix.apply(fixes, to: transcript)
    }

    /// Corrects one character of a word on the page and finds the words shown again, so the
    /// readout, the sentence Keep saves and the copy all read as corrected.
    private func fix(_ word: FoundWord, onLine line: Int, _ index: Int, _ replacement: String) {
        let text = fixed
        let start = transcriptLines.offsets(of: word.first, onLine: line, in: text)
        let shown = words.filter { lines[line].contains($0.first) }
        let spanStart =
            shown.map { transcriptLines.offsets(of: $0.first, onLine: line, in: text).inLine }.min()
            ?? start.inLine
        let spanEnd =
            shown.map {
                transcriptLines.offsets(of: $0.first, onLine: line, in: text).inLine
                    + $0.surface.count
            }.max() ?? start.inLine + word.surface.count
        fixes.append(
            TextFix(offset: start.inTranscript + index, length: 1, replacement: replacement))
        refind = (line, spanStart..<(spanEnd + replacement.count - 1))
    }

    private var tokenizer: (any Tokenizer)? {
        choice.tokenizer
    }

    private func tokenize() {
        words = []
        keptSurfaces = []
        transcriptLines = TranscriptLines(fixed)
        lines = transcriptLines.lines.map { tokenizer?.tokens(in: $0) ?? [] }
        if let refind, lines.indices.contains(refind.line) {
            let tokens = WordFinder.tokens(
                lines[refind.line], overlapping: refind.range,
                in: transcriptLines.lines[refind.line])
            words = WordFinder.words(in: tokens, dictionary: JMdict.bundled)
            for entry in words.compactMap(\.entries.first) {
                Cards.noteLookup(of: entry, from: .page)
            }
        }
        refind = nil
    }

    /// The strip's own tokens on that line are preferred, so Keep knows the sentence.
    private func showSelection() async {
        let text = selection.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let tokenizer else {
            selection.looking = false
            return
        }
        // The spinner is drawn before the lookup holds the main thread. It goes when the latest
        // lookup ends however it ends, cancelled included, so the page is never left blocked.
        let lookup = UUID()
        currentLookup = lookup
        selection.looking = true
        defer { if currentLookup == lookup { selection.looking = false } }
        try? await Task.sleep(for: .milliseconds(30))
        guard !Task.isCancelled else { return }
        let found = WordFinder.words(in: tokenizer.tokens(in: text), dictionary: JMdict.bundled)
        if let line = transcriptLines.lineIndex(
            ofSelection: selection.range, in: currentTranscript, pageOffset: pageOffset,
            transcript: fixed, fixes: fixes)
        {
            words = found.map { $0.aligned(to: lines[line]) ?? $0 }
        } else {
            words = found
        }
        // The history's write is a file; off the main thread, it costs the reader nothing.
        let entries = words.compactMap(\.entries.first)
        Task.detached(priority: .utility) {
            for entry in entries { Cards.noteLookup(of: entry, from: .page) }
        }
    }

    private func keep(_ word: FoundWord) {
        let keeper = SentenceKeeper(
            transcript: fixed, transcriptLines: transcriptLines, tokenLines: lines, source: nil)
        guard let store = Cards.store, let sighting = keeper.sighting(for: word) else { return }
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
