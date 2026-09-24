import SwiftUI

/// Side by side on a shared baseline while the row fits the width, stacked when the type size
/// outgrows it. A layout rather than `ViewThatFits`, which in a list row can report the
/// stacked height while showing the row side by side, leaving the row tall and half empty.
struct FitsOrStacks: Layout {
    var spacing: CGFloat = 12

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        if let row = row(subviews, width: width) {
            return CGSize(width: proposal.width ?? row.width, height: row.height)
        }
        let sizes = subviews.map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)) }
        return CGSize(
            width: proposal.width ?? sizes.map(\.width).max() ?? 0,
            height: sizes.map(\.height).reduce(0, +) + spacing / 2
                * CGFloat(max(sizes.count - 1, 0)))
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        if let row = row(subviews, width: bounds.width) {
            var x = bounds.minX
            for (index, subview) in subviews.enumerated() {
                subview.place(
                    at: CGPoint(x: x, y: bounds.minY + row.tops[index]),
                    proposal: ProposedViewSize(width: row.widths[index], height: nil))
                x += row.widths[index] + spacing
            }
            return
        }
        var y = bounds.minY
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
            subview.place(
                at: CGPoint(x: bounds.minX, y: y),
                proposal: ProposedViewSize(width: bounds.width, height: nil))
            y += size.height + spacing / 2
        }
    }

    /// The side-by-side arrangement, or nil when it does not fit: each view at its own width,
    /// the room left shared among those that can grow, all on the first text baseline.
    private struct Row {
        let width: CGFloat
        let height: CGFloat
        let widths: [CGFloat]
        let tops: [CGFloat]
    }

    private func row(_ subviews: Subviews, width: CGFloat) -> Row? {
        let ideal = subviews.map { $0.sizeThatFits(.unspecified) }
        let needed = ideal.map(\.width).reduce(0, +) + spacing * CGFloat(max(subviews.count - 1, 0))
        guard needed <= width else { return nil }
        var widths = ideal.map(\.width)
        if width.isFinite {
            let growing = subviews.indices.filter {
                subviews[$0].sizeThatFits(ProposedViewSize(width: width, height: nil)).width
                    > ideal[$0].width + 0.5
            }
            for index in growing { widths[index] += (width - needed) / CGFloat(growing.count) }
        }
        let baselines = subviews.indices.map {
            subviews[$0].dimensions(in: ProposedViewSize(width: widths[$0], height: nil))[
                .firstTextBaseline]
        }
        let top = baselines.max() ?? 0
        let tops = baselines.map { top - $0 }
        let height = subviews.indices.map { tops[$0] + ideal[$0].height }.max() ?? 0
        return Row(width: min(needed, width), height: height, widths: widths, tops: tops)
    }
}
