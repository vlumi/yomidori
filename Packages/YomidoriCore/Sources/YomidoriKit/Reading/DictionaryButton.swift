import SwiftUI

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
