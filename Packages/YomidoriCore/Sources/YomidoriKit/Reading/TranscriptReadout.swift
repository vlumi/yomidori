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
    @ObservedObject var selection: LiveTextSelection
    /// A sentence left open on the previous page, waiting for this one.
    @Binding var openSentence: OpenSentence?
    @State private var choice: Choice = .system
    @State private var lines: [[Token]] = []
    /// Where each line starts in the transcript, so a token maps back into it.
    @State private var lineStarts: [String.Index] = []
    @State private var selected: Token?
    @State private var kept: Card?
    @State private var stillID: UUID?
    /// Where the reader is: a book and a page, in their words, kept between stills and launches.
    @AppStorage("source") private var source = ""

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
            TextField(text: $source) {
                Text("Book, page", bundle: .module)
            }
            .textFieldStyle(.roundedBorder)
            .font(.callout)
            if let openSentence {
                continued(openSentence)
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
        .task(id: "\(choice)|\(selection.text)") { showSelection() }
    }

    /// A word selected on the still itself, through Live Text's own selection, shown
    /// as if tapped in the strip: the selection's line is the sentence, and its first
    /// word the word. A selection of nothing changes nothing.
    private func showSelection() {
        let text = selection.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let tokenizer: (any Tokenizer)? =
            choice == .system ? SystemTokenizer() : MeCabTokenizer.shared
        guard let word = tokenizer?.tokens(in: text).first(where: \.isWord) else { return }
        // Prefer the strip's own token for the line it stands in, so Keep knows the sentence.
        if let lineIndex = lineIndex(of: selection.range),
            let match = lines[lineIndex].first(where: { $0.surface == word.surface })
        {
            selected = match
        } else {
            selected = word
        }
    }

    /// The transcript line a range of the transcript falls in.
    private func lineIndex(of range: Range<String.Index>?) -> Int? {
        guard let range, range.lowerBound < transcript.endIndex else { return nil }
        let before = transcript[transcript.startIndex..<range.lowerBound]
        let newlines = before.filter { $0 == "\n" }.count
        let empties = before.split(separator: "\n", omittingEmptySubsequences: false).dropLast()
            .filter(\.isEmpty).count
        return newlines - empties
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
                DictionaryButton(
                    term: entries.first?.headword ?? token.dictionaryForm ?? token.surface)
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
            if sentence(around: token)?.sentence.isOpen == true {
                Button {
                    leaveOpen(token, entry: entry)
                } label: {
                    Label {
                        Text("Continues on next page", bundle: .module)
                    } icon: {
                        Image(systemName: "arrow.turn.down.right")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    /// The sentence around a token, in the whole transcript, and where the token
    /// starts in it.
    private func sentence(around token: Token) -> (sentence: Sentence, start: String.Index)? {
        guard let lineIndex = lines.firstIndex(where: { $0.contains(token) }),
            lineIndex < lineStarts.count
        else { return nil }
        let line = String(
            transcript.split(separator: "\n", omittingEmptySubsequences: true)[lineIndex])
        let offset = line.distance(from: line.startIndex, to: token.range.lowerBound)
        let start = transcript.index(lineStarts[lineIndex], offsetBy: offset)
        return (Sentence.around(start, in: transcript), start)
    }

    private func keep(_ token: Token, entry: DictionaryEntry?) {
        guard let store = Cards.store, let found = sentence(around: token) else { return }
        if stillID == nil, let still {
            stillID = try? StillArchive.save(still)
        }
        let sighting = Sighting(
            sentence: found.sentence.text, surface: token.surface,
            offset: found.sentence.offset(of: found.start, in: transcript),
            stillID: stillID, source: source.isEmpty ? nil : source, date: Date())
        let headword = entry?.headword ?? token.dictionaryForm ?? token.surface
        let reading = Kana.hiragana(entry?.readings.first ?? token.reading)
        kept = try? store.keep(sighting, headword: headword, reading: reading, entryID: entry?.id)
    }

    /// Leave the sentence open for the next page instead of keeping it now.
    private func leaveOpen(_ token: Token, entry: DictionaryEntry?) {
        guard let found = sentence(around: token) else { return }
        if stillID == nil, let still {
            stillID = try? StillArchive.save(still)
        }
        openSentence = OpenSentence(
            fragment: found.sentence.text, surface: token.surface,
            offset: found.sentence.offset(of: found.start, in: transcript),
            headword: entry?.headword ?? token.dictionaryForm ?? token.surface,
            reading: Kana.hiragana(entry?.readings.first ?? token.reading), entryID: entry?.id,
            stillID: stillID, source: source.isEmpty ? nil : source)
    }

    /// The previous page's open sentence, with this page's beginning as its end.
    private func continued(_ open: OpenSentence) -> some View {
        let continuation = Sentence.continuation(of: transcript)
        return VStack(alignment: .leading, spacing: 6) {
            Text("Continued from the previous page", bundle: .module)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(verbatim: open.fragment + continuation.text)
                .font(.callout)
            HStack {
                Button {
                    keepWhole(open, continuation: continuation)
                } label: {
                    Text("Keep the whole sentence", bundle: .module)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                Button {
                    openSentence = nil
                } label: {
                    Text("Discard", bundle: .module)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(10)
        .background(Palette.nightGreen.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private func keepWhole(_ open: OpenSentence, continuation: Sentence) {
        guard let store = Cards.store else { return }
        if stillID == nil, let still {
            stillID = try? StillArchive.save(still)
        }
        let sighting = Sighting(
            sentence: open.fragment + continuation.text, surface: open.surface, offset: open.offset,
            stillID: open.stillID, continuationStillID: stillID, source: open.source, date: Date())
        kept = try? store.keep(
            sighting, headword: open.headword, reading: open.reading, entryID: open.entryID)
        openSentence = nil
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
        let rawLines = transcript.split(separator: "\n", omittingEmptySubsequences: true)
        lines = rawLines.map { tokenizer?.tokens(in: String($0)) ?? [] }
        lineStarts = rawLines.map(\.startIndex)
    }
}
