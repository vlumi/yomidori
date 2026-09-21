import SwiftUI

#if os(iOS)
import UIKit
#endif

/// The system's own dictionaries, shown as a view and never quoted; none off iOS.
enum ReferenceLibrary {
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
