import Foundation

/// Live Text tells no one when the selection changes, so the interaction's owner polls it
/// while showing.
@MainActor
final class LiveTextSelection: ObservableObject {
    @Published var text = ""
    @Published var range: Range<String.Index>?
}
