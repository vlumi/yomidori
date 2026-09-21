import SwiftUI

/// A button that opens the system dictionary on a term, present only when the
/// dictionary has it.
struct DictionaryButton: View {
    let term: String
    @State private var shown = false

    var body: some View {
        if ReferenceLibrary.hasDefinition(for: term) {
            Button {
                shown = true
            } label: {
                Label {
                    Text("Dictionary", bundle: .module)
                } icon: {
                    Image(systemName: "character.book.closed")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .sheet(isPresented: $shown) {
                ReferenceLibraryView(term: term)
                    .ignoresSafeArea()
            }
        }
    }
}
