import SwiftUI

struct EngineLine: View {
    let name: LocalizedStringKey
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name, bundle: .module)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(verbatim: text.isEmpty ? "—" : text)
                .font(.body)
                .textSelection(.enabled)
                .lineLimit(3)
        }
    }
}
