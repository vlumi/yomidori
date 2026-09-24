import SwiftUI
import YomidoriCore
import YomidoriDictionary
import YomidoriMeCab

/// The drawer under a page: the words selected, and the page's text as its chunks. The page is
/// read into words once (`PageReading`), when its text is known or changes, and a selection
/// is a range of that text, made on the page, in the strip or on the picture alike.
struct TranscriptReadout: View {
    let transcript: String
    let currentTranscript: String
    /// Where the page on screen starts in the joined transcript, in characters.
    let pageOffset: Int
    @ObservedObject var selection: LiveTextSelection
    @EnvironmentObject private var page: CaptureState
    @AppStorage(TokenizerChoice.key) private var choice: TokenizerChoice = .system
    @State private var keptSurfaces: Set<String> = []
    /// Where the selection goes once a fix has been read in.
    @State private var afterFix: Range<Int>?
    @AppStorage(SettingsKey.transcriptExpanded) private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if page.reading == nil {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Reading the words…", bundle: .module)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
            } else if let reading = page.reading, let range = page.selectedRange {
                selectionRows(reading, range)
            }
            if choice == .mecab, MeCabTokenizer.shared == nil {
                Text("MeCab could not load its dictionary.", bundle: .module)
                    .foregroundStyle(.secondary)
            }
            if let reading = page.reading {
                strip(reading)
            }
        }
        .task(id: "\(choice)|\(fixed)") { await read() }
        .onChange(of: selection.range) { selectionOnPage() }
        .onChange(of: page.selectedRange) { _, range in
            requestOnPage(range)
            noteLookups(range)
        }
    }

    private func strip(_ reading: PageReading) -> some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(reading.lines.lines.indices, id: \.self) { line in
                    ChunkFlow(
                        chunks: reading.chunks.filter { $0.line == line },
                        selected: page.selectedRange,
                        select: { page.selectedRange = $0.range },
                        extend: extend)
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

    /// The selection stretched to a chunk: from where it starts to the chunk, whichever way.
    private func extend(_ chunk: PageReading.Chunk) {
        guard let range = page.selectedRange else {
            if chunk.isWord { page.selectedRange = chunk.range }
            return
        }
        page.selectedRange =
            min(
                range.lowerBound, chunk.range.lowerBound)..<max(
                range.upperBound, chunk.range.upperBound)
    }

    /// Several chunks: the phrase first, looked up whole when the dictionary knows it, then
    /// each word. One chunk: its word.
    @ViewBuilder private func selectionRows(_ reading: PageReading, _ range: Range<Int>)
        -> some View
    {
        let chunks = reading.chunks(in: range)
        let words = chunks.filter(\.isWord)
        if chunks.count > 1 {
            PhraseRow(reading: reading, chunks: chunks) {
                keep($0, onLine: chunks[0].line, in: reading)
            }
            if !words.isEmpty { Divider() }
        }
        ForEach(words) { chunk in
            if chunk.id != words.first?.id { Divider() }
            wordReadout(chunk, in: reading)
        }
    }

    private func wordReadout(_ chunk: PageReading.Chunk, in reading: PageReading) -> some View {
        WordReadout(
            word: chunk.word,
            accent: chunk.word.entries.first.flatMap { JMdict.bundled?.pitchAccent(of: $0) },
            kept: keptSurfaces.contains(chunk.surface), canKeep: Cards.store != nil,
            fix: { index, replacement in fix(chunk, index, replacement) }
        ) {
            keep(chunk.word, onLine: chunk.line, in: reading)
        }
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

    /// The transcript as recognized, with the reader's corrections in.
    private var fixed: String {
        TextFix.apply(page.fixes, to: transcript)
    }

    /// The page read into words, off the main thread; taps wait until it is done.
    /// Not again for a page already read this way: a return to the tab keeps the reading
    /// and the selection.
    private func read() async {
        let text = fixed
        let key = "\(choice)|\(text)"
        guard page.reading == nil || page.readingKey != key else {
            selection.looking = false
            return
        }
        let previous = afterFix ?? page.selectedRange
        page.reading = nil
        selection.looking = true
        let reading = await PageReader.shared.read(text, with: choice)
        guard !Task.isCancelled else { return }
        keptSurfaces = []
        page.reading = reading
        page.readingKey = key
        page.selectedRange = previous.flatMap(reading.whole)
        afterFix = nil
        selection.looking = false
    }

    /// Corrects one character of a word and reads the page again, the selection kept on it,
    /// so the readout, Keep's sentence and the copy all read as corrected.
    private func fix(_ chunk: PageReading.Chunk, _ index: Int, _ replacement: String) {
        page.fixes.append(
            TextFix(offset: chunk.range.lowerBound + index, length: 1, replacement: replacement))
        let range = page.selectedRange ?? chunk.range
        afterFix = range.lowerBound..<(range.upperBound + replacement.count - 1)
    }

    /// A selection made on the page itself (Live Text's, the pasted text's), as whole chunks.
    private func selectionOnPage() {
        guard let reading = page.reading, let range = selection.range,
            range.lowerBound >= 0, range.upperBound <= currentTranscript.count
        else { return }
        let start = pageOffset + range.lowerBound
        let end = pageOffset + range.upperBound
        let mapped =
            TextFix.map(
                offset: start, through: page.fixes)..<TextFix.map(offset: end, through: page.fixes)
        guard !mapped.isEmpty, let whole = reading.whole(mapped), whole != page.selectedRange else {
            return
        }
        page.selectedRange = whole
    }

    /// The selection shown by the page view too, where it falls on the page on screen and the
    /// text is as recognized.
    private func requestOnPage(_ range: Range<Int>?) {
        guard let range, page.fixes.isEmpty else {
            selection.requested = nil
            return
        }
        let start = range.lowerBound - pageOffset
        let end = range.upperBound - pageOffset
        guard start >= 0, end <= currentTranscript.count else {
            selection.requested = nil
            return
        }
        selection.requested = start..<end
    }

    /// The words selected go into the lookup history, off the main thread.
    private func noteLookups(_ range: Range<Int>?) {
        guard let reading = page.reading, let range else { return }
        let entries = reading.chunks(in: range).filter(\.isWord).compactMap(\.word.entries.first)
        Task.detached(priority: .utility) {
            for entry in entries { Cards.noteLookup(of: entry, from: .page) }
        }
    }

    private func keep(_ word: FoundWord, onLine line: Int, in reading: PageReading) {
        let keeper = SentenceKeeper(
            transcript: reading.text, transcriptLines: reading.lines,
            tokenLines: reading.tokenLines,
            source: nil)
        guard let store = Cards.store, let sighting = keeper.sighting(for: word, onLine: line)
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

/// Several chunks selected together: the phrase as it stands on the page, and, when the
/// dictionary knows it whole (an expression the tokenizer split), its entry as a word.
private struct PhraseRow: View {
    let reading: PageReading
    let chunks: [PageReading.Chunk]
    let keep: (FoundWord) -> Void

    var body: some View {
        let phrase = chunks.map(\.surface).joined()
        let entries =
            JMdict.bundled?.entries(forAny: Deinflector.candidates(for: phrase)) ?? []
        let tokens = chunks.flatMap(\.word.tokens)
        if !entries.isEmpty, !tokens.isEmpty {
            WordReadout(
                word: FoundWord(tokens: tokens, entries: entries),
                accent: entries.first.flatMap { JMdict.bundled?.pitchAccent(of: $0) },
                kept: false, canKeep: Cards.store != nil
            ) {
                keep(FoundWord(tokens: tokens, entries: entries))
            }
        } else {
            Text(japanese: phrase)
                .font(.title3)
                .textSelection(.enabled)
        }
    }
}
