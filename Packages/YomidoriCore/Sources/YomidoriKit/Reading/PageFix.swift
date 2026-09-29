import SwiftUI

/// A correction to a word or a phrase on the page: one character put right, or the whole of
/// it retyped.
enum PageFix: Equatable {
    case character(index: Int, replacement: String)
    case whole(String)
}

/// Opens the sheet that fixes the text. What is chosen there is applied once the sheet is
/// gone: applying it reads the page again and takes this row with it, and a row that goes
/// while its sheet is still dismissing leaves the screen deaf to every tap.
struct FixButton: View {
    let surface: String
    let fix: (PageFix) -> Void
    @State private var fixing = false
    @State private var pending: PageFix?

    var body: some View {
        Button {
            fixing = true
        } label: {
            Label {
                Text("Fix the text", bundle: .module)
            } icon: {
                Image(systemName: "character.cursor.ibeam")
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .sheet(isPresented: $fixing) {
            if let pending {
                self.pending = nil
                fix(pending)
            }
        } content: {
            CharacterFixView(surface: surface) { pending = $0 }
        }
    }
}
