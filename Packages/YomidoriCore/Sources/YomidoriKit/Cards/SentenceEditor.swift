import SwiftUI
import YomidoriCore

/// The sentence of one sighting, as the reader corrects what the recognizer read.
struct SentenceEditor: View {
    let sighting: Sighting
    let save: (Sighting) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .font(.title3)
                .padding()
                .navigationTitle(Text("Edit the sentence", bundle: .module))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Text("Cancel", bundle: .module)
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            save(sighting.withSentence(text))
                            dismiss()
                        } label: {
                            Text("Save", bundle: .module)
                        }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
        }
        .onAppear { text = sighting.sentence }
    }
}
