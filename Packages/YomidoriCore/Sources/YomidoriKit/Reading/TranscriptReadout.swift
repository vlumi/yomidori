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
    @State private var choice: Choice = .system
    @State private var lines: [[Token]] = []
    @State private var selected: Token?

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

    /// The tapped word, large: its reading, its dictionary form when known, and the
    /// meaning folded under it, since the reading is what was asked for.
    private func word(_ token: Token) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(verbatim: token.surface)
                    .font(.title)
                Text(verbatim: token.reading)
                    .font(.title3)
                    .foregroundStyle(Palette.nightGreen)
                if let form = token.dictionaryForm {
                    Text(verbatim: form)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .textSelection(.enabled)
            if let dictionary = JMdict.bundled {
                DisclosureGroup {
                    meaning(of: token, in: dictionary)
                } label: {
                    Text("Meaning", bundle: .module)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tint(.secondary)
            }
        }
    }

    /// The word's entries: the dictionary form first, then the word as it stands, then
    /// its reading. A word with no entry is either rare or misread.
    private func meaning(of token: Token, in dictionary: some WordDictionary) -> some View {
        let candidates = [token.dictionaryForm, token.surface, token.reading].compactMap { $0 }
        let entries = candidates.lazy.map(dictionary.entries(matching:)).first { !$0.isEmpty } ?? []
        return VStack(alignment: .leading, spacing: 6) {
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
