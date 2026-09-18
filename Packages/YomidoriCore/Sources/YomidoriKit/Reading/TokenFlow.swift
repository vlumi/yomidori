import SwiftUI
import YomidoriCore

/// One line of text as its tokens, wrapping like text: each word with its reading
/// over it where the reading says something the word does not, the tapped word filled.
struct TokenFlow: View {
    let tokens: [Token]
    @Binding var selected: Token?

    var body: some View {
        FlowLayout(spacing: 4) {
            ForEach(tokens.indices, id: \.self) { index in
                let token = tokens[index]
                VStack(spacing: 0) {
                    Text(
                        verbatim: token.isWord && token.reading != token.surface
                            ? token.reading : " "
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    Text(verbatim: token.surface)
                        .font(.title3)
                }
                .padding(.horizontal, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(token == selected ? Palette.nightGreen.opacity(0.25) : .clear)
                )
                .onTapGesture { selected = token.isWord ? token : nil }
            }
        }
    }
}

/// Rows of subviews that wrap at the width offered, left to right, top to bottom.
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
