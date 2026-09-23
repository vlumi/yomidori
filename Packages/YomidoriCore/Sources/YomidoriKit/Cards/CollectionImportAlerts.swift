import SwiftUI

extension View {
    /// The note after an import, or that the file was not a collection.
    func collectionImportAlerts(imported: Binding<CollectionImport?>, failed: Binding<Bool>)
        -> some View
    {
        alert(item: imported) { done in
            Alert(
                title: Text(verbatim: done.name),
                message: Text(
                    "\(done.added) new words, waiting for a lesson; \(done.joined) you already had.",
                    bundle: .module))
        }
        .alert(
            Text("That file is not a Yomidori collection.", bundle: .module), isPresented: failed
        ) {}
    }
}
