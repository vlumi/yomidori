import SwiftUI
import YomidoriCore

struct TokenFlow: View {
    let tokens: [Token]
    let selected: Token?
    let onTap: (Token) -> Void
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiate

    var body: some View {
        FlowLayout(spacing: 4) {
            ForEach(tokens.indices, id: \.self) { index in
                let token = tokens[index]
                let hasReading = token.isWord && token.reading != token.surface
                let isSelected = token == selected
                Button {
                    onTap(token)
                } label: {
                    VStack(spacing: 0) {
                        Text(verbatim: hasReading ? token.reading : " ")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(verbatim: token.surface)
                            .font(.title3)
                    }
                    .padding(.horizontal, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isSelected ? Palette.nightGreen.opacity(0.25) : .clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(
                                Palette.nightGreen, lineWidth: isSelected && differentiate ? 2 : 0)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    Text(japanese: hasReading ? "\(token.surface)、\(token.reading)" : token.surface)
                )
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}
