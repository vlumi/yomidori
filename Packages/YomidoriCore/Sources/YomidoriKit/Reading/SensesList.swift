import SwiftUI
import YomidoriCore

/// An entry's senses, numbered, glosses joined; the first few.
struct SensesList: View {
    let entry: DictionaryEntry
    var limit = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(entry.senses.prefix(limit).indices, id: \.self) { index in
                Text(
                    verbatim: "\(index + 1). \(entry.senses[index].glosses.joined(separator: "; "))"
                )
                .font(.callout)
            }
        }
    }
}

/// The meaning folded away, since the reading is what was asked for.
struct MeaningFold<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        DisclosureGroup {
            content()
                .padding(.top, 2)
        } label: {
            Text("Meaning", bundle: .module)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .tint(.secondary)
    }
}
