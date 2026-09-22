import SwiftUI
import YomidoriCore

/// One collection: its name, note, tags and cover; new when the name is still empty.
struct CollectionEditor: View {
    @State var collection: Collection
    @Environment(\.dismiss) private var dismiss
    @State private var scanning = false
    @State private var others: [Collection] = []

    var body: some View {
        Form {
            Section {
                HStack(alignment: .top, spacing: 16) {
                    if let coverID = collection.coverID, let image = StillArchive.load(coverID) {
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 90, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            scanning = true
                        } label: {
                            Label {
                                Text("Scan the cover", bundle: .module)
                            } icon: {
                                Image(systemName: "camera.viewfinder")
                            }
                        }
                        if collection.coverID != nil {
                            Button(role: .destructive) {
                                collection.coverID = nil
                            } label: {
                                Label {
                                    Text("Remove the cover", bundle: .module)
                                } icon: {
                                    Image(systemName: "photo.badge.minus")
                                }
                            }
                        }
                    }
                }
            } footer: {
                Text(
                    "The words on the cover are read, so the name can be picked, not typed.",
                    bundle: .module)
            }
            Section {
                LabeledContent {
                    TextField(text: $collection.name) {
                        Text("Required", bundle: .module)
                    }
                    .multilineTextAlignment(.trailing)
                } label: {
                    Text("Name", bundle: .module)
                }
                LabeledContent {
                    TextField(text: $collection.note) {
                        Text("An author, say", bundle: .module)
                    }
                    .multilineTextAlignment(.trailing)
                } label: {
                    Text("Note", bundle: .module)
                }
            }
            TagsEditor(tags: $collection.tags, known: others.allTags)
        }
        .navigationTitle(Text(verbatim: collection.name.isEmpty ? "" : collection.name))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    save()
                } label: {
                    Text("Save", bundle: .module)
                }
                .disabled(collection.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .sheet(isPresented: $scanning) {
            CoverScanView(collection: $collection)
        }
        .onAppear {
            others = (Cards.collections?.collections() ?? []).filter { $0.id != collection.id }
        }
        .tint(Palette.nightGreen)
    }

    private func save() {
        var saved = collection
        saved.name = saved.name.trimmingCharacters(in: .whitespaces)
        saved.note = saved.note.trimmingCharacters(in: .whitespaces)
        try? Cards.collections?.save(saved)
        dismiss()
    }
}
