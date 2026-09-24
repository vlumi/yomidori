import Foundation

/// Live Text tells no one when the selection changes, so the interaction's owner polls it
/// while showing.
@MainActor
final class LiveTextSelection: ObservableObject {
    @Published var text = ""
    @Published var range: Range<String.Index>?
    /// The page is being read into its words; it takes no tap or selection meanwhile.
    @Published var looking = false
    /// A selection made elsewhere (the strip, a Vision tap) for the page view to show as its
    /// own, as a range of the page's own text; the page reports it back through `text` and
    /// `range`, which then change nothing.
    @Published var requested: Range<String.Index>?
}
