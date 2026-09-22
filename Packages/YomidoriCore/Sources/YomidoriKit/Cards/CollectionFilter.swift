import SwiftUI
import YomidoriCore

/// Which collections to show: any number of them, a tag standing for every collection that
/// carries it, or all cards.
struct CollectionFilter: View {
    let collections: [Collection]
    @Binding var chosen: Set<UUID>

    var body: some View {
        Menu {
            Button {
                chosen = []
            } label: {
                if chosen.isEmpty {
                    Label {
                        Text("All cards", bundle: .module)
                    } icon: {
                        Image(systemName: "checkmark")
                    }
                } else {
                    Text("All cards", bundle: .module)
                }
            }
            Section {
                ForEach(collections) { collection in
                    Toggle(
                        isOn: Binding(
                            get: { chosen.contains(collection.id) },
                            set: { _ in toggle(collection.id) })
                    ) {
                        Text(verbatim: collection.name)
                    }
                }
            }
            let tags = collections.allTags
            if !tags.isEmpty {
                Section {
                    ForEach(tags, id: \.self) { tag in
                        Button {
                            for collection in collections where collection.hasTag(tag) {
                                chosen.insert(collection.id)
                            }
                        } label: {
                            Label(tag, systemImage: "tag")
                        }
                    }
                } header: {
                    Text("By tag", bundle: .module)
                }
            }
        } label: {
            Label {
                Text("Collection", bundle: .module)
            } icon: {
                Image(
                    systemName: chosen.isEmpty
                        ? "line.3.horizontal.decrease.circle"
                        : "line.3.horizontal.decrease.circle.fill")
            }
        }
    }

    private func toggle(_ id: UUID) {
        if chosen.contains(id) { chosen.remove(id) } else { chosen.insert(id) }
    }
}
