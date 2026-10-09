import SwiftUI

/// ⌘F: the dictionary's field, from anywhere in the dictionary — a button with no face,
/// for its key alone.
struct FieldShortcut: View {
    let focus: () -> Void

    var body: some View {
        Button(action: focus) {
            EmptyView()
        }
        .keyboardShortcut("f", modifiers: .command)
        .frame(width: 0, height: 0)
        .opacity(0)
    }
}
