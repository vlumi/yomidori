import SwiftUI

/// The meaning of a review card, folded so the reading is what is asked for.
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
