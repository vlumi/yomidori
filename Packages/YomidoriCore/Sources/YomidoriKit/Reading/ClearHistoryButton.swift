import SwiftUI

/// Forgets every word looked up — but not by one tap: on the phone the item sits in a menu,
/// in red and saying what it does, and on either platform it asks with the count before it
/// does it, since a whole history went twice to a thumb that meant something else. The
/// history's generation is bumped so its view reloads.
struct ClearHistoryButton: View {
    @Binding var generation: Int
    @State private var asking = false
    /// Counted when asked, not on every render: the history is a file.
    @State private var count = 0

    var body: some View {
        control
            .help(Text("Forget every word looked up", bundle: .module))
            .confirmationDialog(
                Text("Forget all \(count) words looked up?", bundle: .module), isPresented: $asking,
                titleVisibility: .visible
            ) {
                Button(role: .destructive) {
                    Cards.write { try Cards.lookups?.clear() }
                    generation += 1
                } label: {
                    Text("Clear the history", bundle: .module)
                }
            } message: {
                Text(
                    "The words themselves stay in the dictionary; only the list of what you looked up goes.",
                    bundle: .module)
            }
    }

    /// The Mac's ellipsis in the title says it asks first; the phone's goes one level down.
    @ViewBuilder private var control: some View {
        #if os(macOS)
        Button(action: ask) {
            Text("Clear the history…", bundle: .module)
        }
        #else
        Menu {
            Button(role: .destructive, action: ask) {
                Label {
                    Text("Clear the history…", bundle: .module)
                } icon: {
                    Image(systemName: "trash")
                }
            }
        } label: {
            Label {
                Text("More", bundle: .module)
            } icon: {
                Image(systemName: "ellipsis.circle")
            }
            .labelStyle(.iconOnly)
        }
        #endif
    }

    private func ask() {
        count = Cards.lookups?.lookups().count ?? 0
        asking = true
    }
}
