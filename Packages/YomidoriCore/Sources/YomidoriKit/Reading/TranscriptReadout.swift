import SwiftUI
import YomidoriCore
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

    /// The tapped word, large: its reading, and its dictionary form when known.
    private func word(_ token: Token) -> some View {
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
