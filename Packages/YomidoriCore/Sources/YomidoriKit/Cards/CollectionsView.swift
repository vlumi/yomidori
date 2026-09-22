import SwiftUI
import YomidoriCore

/// The collections: made, renamed and removed here; removing one only takes it off its cards.
struct CollectionsView: View {
    @State private var collections: [Collection] = []
    @State private var editing: Collection?
    @State private var name = ""
    @State private var adding = false

    var body: some View {
        List {
            ForEach(collections) { collection in
                Button {
                    name = collection.name
                    editing = collection
                } label: {
                    HStack {
                        Text(verbatim: collection.name)
                        Spacer()
                        Text(verbatim: "\(count(in: collection))")
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.primary)
            }
            .onDelete { offsets in
                for index in offsets {
                    Cards.removeCollection(collections[index])
                }
                reload()
            }
            if collections.isEmpty {
                Text("No collections yet. A book, say.", bundle: .module)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(Text("Collections", bundle: .module))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    name = ""
                    adding = true
                } label: {
                    Label {
                        Text("New collection…", bundle: .module)
                    } icon: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .alert(Text("New collection", bundle: .module), isPresented: $adding) {
            TextField(text: $name) {
                Text("Name", bundle: .module)
            }
            Button {
                save(Collection(name: name))
            } label: {
                Text("Add", bundle: .module)
            }
            Button(role: .cancel) {
            } label: {
                Text("Cancel", bundle: .module)
            }
        }
        .alert(
            Text("Rename", bundle: .module),
            isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })
        ) {
            TextField(text: $name) {
                Text("Name", bundle: .module)
            }
            Button {
                if var collection = editing {
                    collection.name = name
                    save(collection)
                }
            } label: {
                Text("Save", bundle: .module)
            }
            Button(role: .cancel) {
            } label: {
                Text("Cancel", bundle: .module)
            }
        }
        .onAppear(perform: reload)
    }

    private func count(in collection: Collection) -> Int {
        (Cards.store?.cards() ?? []).filter { $0.collectionIDs.contains(collection.id) }.count
    }

    private func save(_ collection: Collection) {
        var named = collection
        named.name = named.name.trimmingCharacters(in: .whitespaces)
        guard !named.name.isEmpty else { return }
        try? Cards.collections?.save(named)
        reload()
    }

    private func reload() {
        collections = Cards.collections?.collections() ?? []
    }
}
