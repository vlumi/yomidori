import Foundation

/// Live Text tells no one when the selection changes, so the interaction's owner polls it
/// while showing.
@MainActor
final class LiveTextSelection: ObservableObject {
    @Published var text = ""
    /// Characters of the page view's own text, never its indices, which belong to that one
    /// text and trap anywhere else.
    @Published var range: Range<Int>?
    /// The page is being read into its words; it takes no tap or selection meanwhile.
    @Published var looking = false
    /// A selection made elsewhere (the strip, a Vision tap) for the page view to show as its
    /// own: characters of the page view's own text, checked against that text when applied,
    /// since indices kept from another text trap. The page reports it back through `text`
    /// and `range`, which then change nothing.
    @Published var requested: Range<Int>?

    /// Nothing selected, nothing asked for: a new page starts clean.
    func clear() {
        text = ""
        range = nil
        requested = nil
        looking = false
    }
}
