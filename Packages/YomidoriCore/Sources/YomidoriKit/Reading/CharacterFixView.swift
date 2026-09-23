import SwiftUI
import YomidoriCore
import YomidoriDictionary

/// One misread character put right: tap it, then pick from the words spelled like the rest,
/// or type it.
struct CharacterFixView: View {
    let surface: String
    let apply: (_ index: Int, _ replacement: String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var index: Int?
    @State private var candidates: [CharacterFix] = []
    @State private var typed = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    FlowLayout(spacing: 8) {
                        ForEach(Array(surface.enumerated()), id: \.offset) { position, character in
                            Button {
                                index = position
                            } label: {
                                Text(japanese: String(character))
                                    .font(.largeTitle)
                                    .frame(minWidth: 52, minHeight: 52)
                            }
                            .buttonStyle(.bordered)
                            .tint(position == index ? Palette.nightGreen : .secondary)
                            .accessibilityAddTraits(position == index ? .isSelected : [])
                        }
                    }
                } footer: {
                    Text("Tap the character that was misread.", bundle: .module)
                }
                if let index {
                    Section {
                        ForEach(candidates, id: \.character) { fix in
                            Button {
                                done(index, fix.character)
                            } label: {
                                row(fix)
                            }
                            .tint(.primary)
                        }
                        if candidates.isEmpty {
                            Text("No word in the dictionary fits.", bundle: .module)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Words that fit", bundle: .module)
                    }
                    Section {
                        TextField(text: $typed) {
                            Text("Or type the right one", bundle: .module)
                        }
                        .font(.title2)
                        .submitLabel(.done)
                        .onSubmit {
                            let replacement = typed.trimmingCharacters(in: .whitespaces)
                            if !replacement.isEmpty { done(index, replacement) }
                        }
                    }
                }
            }
            .navigationTitle(Text("Fix a character", bundle: .module))
            .navigationBarTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel", bundle: .module)
                    }
                }
            }
            .task(id: index) {
                typed = ""
                guard let index, let dictionary = JMdict.bundled else {
                    candidates = []
                    return
                }
                candidates = CharacterFix.candidates(
                    for: surface, at: index, dictionary: dictionary)
            }
            .onAppear {
                if surface.count == 1 { index = 0 }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(_ fix: CharacterFix) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(japanese: fix.character)
                .font(.title)
                .foregroundStyle(Palette.nightGreen)
            Text(japanese: fix.entry.headword)
            Text(japanese: Kana.hiragana(fix.entry.readings.first ?? ""))
                .foregroundStyle(.secondary)
            Spacer()
            Text(verbatim: fix.entry.senses.first?.glosses.first ?? "")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func done(_ index: Int, _ replacement: String) {
        apply(index, replacement)
        dismiss()
    }
}
