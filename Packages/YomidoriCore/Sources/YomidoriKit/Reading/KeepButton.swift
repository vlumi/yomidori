import SwiftUI

/// Keep, or the mark of a word already kept, which opens its card.
struct KeepButton: View {
    let kept: Bool
    let canKeep: Bool
    let keep: () -> Void
    var open: (() -> Void)?

    var body: some View {
        if kept {
            Button {
                open?()
            } label: {
                Image(systemName: "checkmark")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .accessibilityLabel(Text("Kept; open the card", bundle: .module))
            .disabled(open == nil)
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
