import Foundation

/// What is selected on the still in Live Text mode: the text, and where it sits in
/// the transcript, so the line it belongs to can be found. Live Text tells no one
/// when the selection changes, so the interaction's owner polls it while showing.
@MainActor
final class LiveTextSelection: ObservableObject {
    @Published var text = ""
    @Published var range: Range<String.Index>?
}
