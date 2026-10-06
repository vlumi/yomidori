import SwiftUI

/// A correction to a word or a phrase on the page: one character put right, or the whole of
/// it retyped.
enum PageFix: Equatable {
    case character(index: Int, replacement: String)
    case whole(String)
}

/// A row's ask to fix its text: what it reads, and what to do with the correction.
struct FixRequest: Identifiable {
    let id = UUID()
    let surface: String
    let apply: (PageFix) -> Void
}

/// The one fix sheet of the readout, hosted by its header, which is always in the tree: a
/// sheet presented by a row went deaf — the whole screen with it — when the correction read
/// the page again and took the row away while the sheet was still dismissing, as a run
/// retyped whole does. What is chosen is applied once the sheet is gone.
@MainActor
final class FixSheet: ObservableObject {
    @Published var request: FixRequest?
    private var pending: (apply: (PageFix) -> Void, fix: PageFix)?

    func ask(_ request: FixRequest) {
        self.request = request
    }

    func chose(_ fix: PageFix, for request: FixRequest) {
        pending = (request.apply, fix)
    }

    func dismissed() {
        guard let pending else { return }
        self.pending = nil
        pending.apply(pending.fix)
    }
}

/// Asks the readout's sheet to fix this row's text.
struct FixButton: View {
    let surface: String
    let fix: (PageFix) -> Void
    @EnvironmentObject private var sheet: FixSheet

    var body: some View {
        Button {
            sheet.ask(FixRequest(surface: surface, apply: fix))
        } label: {
            Label {
                Text("Fix the text", bundle: .module)
            } icon: {
                Image(systemName: "character.cursor.ibeam")
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

extension View {
    /// Presents the readout's fix sheet from here, a view that stays while the page is
    /// read again.
    func fixSheet(_ sheet: FixSheet) -> some View {
        self.sheet(item: Binding(get: { sheet.request }, set: { sheet.request = $0 })) {
            sheet.dismissed()
        } content: { request in
            CharacterFixView(surface: request.surface) { sheet.chose($0, for: request) }
                .sheetSize(width: 480, height: 560)
        }
    }
}
