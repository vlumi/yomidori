import SwiftUI
import YomidoriCore

/// A collection's tags as chips, each removable; a field adds one, and the tags the other
/// collections use are a tap away.
struct TagsEditor: View {
    @Binding var tags: [String]
    let known: [String]
    @State private var draft = ""

    var body: some View {
        Section {
            if !tags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        chip(tag, systemImage: "xmark") { tags.removeAll { $0 == tag } }
                            .tint(Palette.nightGreen)
                            .accessibilityLabel(Text("Remove tag \(tag)", bundle: .module))
                    }
                }
            }
            HStack {
                TextField(text: $draft) {
                    Text("Add a tag", bundle: .module)
                }
                .onSubmit(add)
                .submitLabel(.done)
                if !draft.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button(action: add) {
                        Image(systemName: "plus.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text("Add a tag", bundle: .module))
                }
            }
            let suggestions = known.filter { !tags.containsTag($0) }
            if !suggestions.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(suggestions, id: \.self) { tag in
                        chip(tag, systemImage: "plus") { tags.append(tag) }
                            .tint(.secondary)
                            .accessibilityLabel(Text("Add tag \(tag)", bundle: .module))
                    }
                }
            }
        } header: {
            Text("Tags", bundle: .module)
        }
    }

    private func chip(_ tag: String, systemImage: String, action: @escaping () -> Void) -> some View
    {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(verbatim: tag)
                Image(systemName: systemImage)
                    .font(.caption2)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .clipShape(Capsule())
    }

    private func add() {
        for tag in Collection.tags(from: draft) where !tags.containsTag(tag) {
            tags.append(tag)
        }
        draft = ""
    }
}
