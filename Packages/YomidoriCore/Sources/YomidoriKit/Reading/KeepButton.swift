import SwiftUI

/// Keep, or the mark of a word already kept.
struct KeepButton: View {
    let kept: Bool
    let canKeep: Bool
    let keep: () -> Void

    var body: some View {
        if kept {
            Image(systemName: "checkmark")
                .foregroundStyle(.secondary)
                .accessibilityLabel(Text("Kept", bundle: .module))
        } else if canKeep {
            Button(action: keep) {
                Label {
                    Text("Keep", bundle: .module)
                } icon: {
                    Image(systemName: "plus.rectangle.on.rectangle")
                }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}
