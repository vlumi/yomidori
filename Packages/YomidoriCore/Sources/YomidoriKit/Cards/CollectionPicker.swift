import SwiftUI
import YomidoriCore

/// The collection a kept word goes into, picked once and remembered: a menu of the
/// collections, none, or a new one named on the spot.
struct CollectionPicker: View {
    @AppStorage(Cards.currentCollectionKey) private var currentID = ""
    @State private var collections: [Collection] = []
    @State private var naming = false
    @State private var name = ""

    var body: some View {
        Menu {
            Button {
                currentID = ""
            } label: {
                if currentID.isEmpty {
                    Label {
                        Text("No collection", bundle: .module)
                    } icon: {
                        Image(systemName: "checkmark")
                    }
                } else {
                    Text("No collection", bundle: .module)
                }
            }
            ForEach(collections) { collection in
                Button {
                    currentID = collection.id.uuidString
                } label: {
                    if currentID == collection.id.uuidString {
                        Label(collection.name, systemImage: "checkmark")
                    } else {
                        Text(verbatim: collection.name)
                    }
                }
            }
            Divider()
            Button {
                name = ""
                naming = true
            } label: {
                Label {
                    Text("New collection…", bundle: .module)
                } icon: {
                    Image(systemName: "plus")
                }
            }
        } label: {
            if let current {
                Label {
                    Text(verbatim: current.name)
                } icon: {
                    Image(systemName: "books.vertical.fill")
                }
                .lineLimit(1)
            } else {
                Image(systemName: "books.vertical")
                    .accessibilityLabel(Text("Collection", bundle: .module))
            }
        }
        .onAppear { collections = Cards.collections?.collections() ?? [] }
        .alert(Text("New collection", bundle: .module), isPresented: $naming) {
            TextField(text: $name) {
                Text("Name", bundle: .module)
            }
            Button {
                create()
            } label: {
                Text("Add", bundle: .module)
            }
            Button(role: .cancel) {
            } label: {
                Text("Cancel", bundle: .module)
            }
        }
    }

    private var current: Collection? {
        collections.first { $0.id.uuidString == currentID }
    }

    private func create() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let collection = Collection(name: trimmed)
        try? Cards.collections?.save(collection)
        collections = Cards.collections?.collections() ?? []
        currentID = collection.id.uuidString
    }
}
