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

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        rows(of: subviews, within: proposal.width ?? .infinity).size
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        let placed = rows(of: subviews, within: bounds.width)
        for (subview, origin) in zip(subviews, placed.origins) {
            subview.place(
                at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                proposal: .unspecified)
        }
    }

    private func rows(of subviews: Subviews, within width: CGFloat) -> (
        origins: [CGPoint], size: CGSize
    ) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return (origins, CGSize(width: widest, height: y + rowHeight))
    }
}
