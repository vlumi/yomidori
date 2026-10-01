import SwiftUI
import YomidoriCore

/// Which collections to show: any number of them, a tag standing for every collection that
/// carries it, or all cards.
struct CollectionFilter: View {
    let collections: [Collection]
    @Binding var chosen: Set<UUID>
    /// Only the cards in no collection: the ones to tidy. Offered while there are any.
    @Binding var unfiled: Bool
    var unfiledCount = 0

    var body: some View {
        Menu {
            Button {
                chosen = []
                unfiled = false
            } label: {
                if chosen.isEmpty, !unfiled {
                    Label {
                        Text("All cards", bundle: .module)
                    } icon: {
                        Image(systemName: "checkmark")
                    }
                } else {
                    Text("All cards", bundle: .module)
                }
            }
            if unfiledCount > 0 || unfiled {
                Button {
                    chosen = []
                    unfiled = true
                } label: {
                    if unfiled {
                        Label {
                            Text("In no collection (\(unfiledCount))", bundle: .module)
                        } icon: {
                            Image(systemName: "checkmark")
                        }
                    } else {
                        Text("In no collection (\(unfiledCount))", bundle: .module)
                    }
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
                            unfiled = false
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
            // What is chosen, as the label: all cards, the one collection, or how many.
            Label {
                if unfiled {
                    Text("In no collection", bundle: .module)
                } else if chosen.isEmpty {
                    Text("All cards", bundle: .module)
                } else if chosen.count == 1,
                    let one = collections.first(where: { chosen.contains($0.id) })
                {
                    Text(verbatim: one.name)
                } else {
                    Text("\(chosen.count) collections", bundle: .module)
                }
            } icon: {
                Image(
                    systemName: chosen.isEmpty && !unfiled
                        ? "line.3.horizontal.decrease.circle"
                        : "line.3.horizontal.decrease.circle.fill")
            }
        }
        .accessibilityLabel(Text("Collection", bundle: .module))
    }

    private func toggle(_ id: UUID) {
        unfiled = false
        if chosen.contains(id) { chosen.remove(id) } else { chosen.insert(id) }
    }
}
