import SwiftUI

#if os(iOS)
import UIKit
#endif

/// The system's own dictionaries, スーパー大辞林 among them on a Japanese phone, through
/// the reference library view: a Japanese meaning at a quality no free data
/// matches, shown as a view, never quoted. Off iOS there is no such library.
enum ReferenceLibrary {
    /// Whether an installed system dictionary has an entry for the term.
    static func hasDefinition(for term: String) -> Bool {
        #if os(iOS)
        UIReferenceLibraryViewController.dictionaryHasDefinition(forTerm: term)
        #else
        false
        #endif
    }
}

#if os(iOS)
struct ReferenceLibraryView: UIViewControllerRepresentable {
    let term: String

    func makeUIViewController(context: Context) -> UIReferenceLibraryViewController {
        UIReferenceLibraryViewController(term: term)
    }

    func updateUIViewController(_ controller: UIReferenceLibraryViewController, context: Context) {}
}
#else
struct ReferenceLibraryView: View {
    let term: String

    var body: some View {
        Text(verbatim: term)
    }
}
#endif
