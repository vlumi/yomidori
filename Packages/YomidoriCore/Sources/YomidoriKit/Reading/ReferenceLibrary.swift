import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
import CoreServices
#endif

/// The system's own dictionaries, shown as a view on iOS and never quoted; on a Mac the
/// Dictionary app, opened on the term.
enum ReferenceLibrary {
    static func hasDefinition(for term: String) -> Bool {
        #if os(iOS)
        UIReferenceLibraryViewController.dictionaryHasDefinition(forTerm: term)
        #elseif os(macOS)
        let range = CFRange(location: 0, length: (term as NSString).length)
        return DCSCopyTextDefinition(nil, term as CFString, range)?.takeRetainedValue() != nil
        #else
        false
        #endif
    }

    #if os(macOS)
    static func open(_ term: String) {
        guard let escaped = term.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
            let url = URL(string: "dict://\(escaped)")
        else { return }
        NSWorkspace.shared.open(url)
    }
    #endif
}

#if os(iOS)
struct ReferenceLibraryView: UIViewControllerRepresentable {
    let term: String

    func makeUIViewController(context: Context) -> UIReferenceLibraryViewController {
        UIReferenceLibraryViewController(term: term)
    }

    func updateUIViewController(_ controller: UIReferenceLibraryViewController, context: Context) {}
}
#endif
