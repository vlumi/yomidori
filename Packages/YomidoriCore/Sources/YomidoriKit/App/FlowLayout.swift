import SwiftUI

/// Rows that wrap, for chips, tokens and pitch choices.
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
            // Half a point of slack: laid out at the width it measured, rounding alone must not
            // push the last item onto a row of its own.
            if x > 0, x + size.width > width + 0.5 {
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
