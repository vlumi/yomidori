import SwiftUI
import YomidoriCore

// MARK: The page beside the words, an iPad on its side

extension CaptureView {
    /// A regular width lying down: the page and the words side by side.
    func columns(in screen: CGSize) -> Bool {
        sizeClass == .regular && screen.width > screen.height
    }

    /// The words column's width for the screen: what the reader set, within a third and
    /// three fifths of the width; the buttons alone while the camera is up.
    func columnWidth(in screen: CGSize) -> Double {
        if still == nil, page.pasted == nil { return Self.buttonsColumnWidth }
        return min(max(wordsWidth, Self.narrowestWordsColumn), screen.width * 0.6)
    }

    /// The words beside the page: what the drawer holds, standing, with the buttons under,
    /// and a handle on its left edge to drag it wider or narrower.
    func wordsColumn(in screen: CGSize) -> some View {
        VStack(spacing: 12) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12, pinnedViews: .sectionHeaders) {
                    words
                }
            }
            buttons
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .frame(width: columnWidth(in: screen))
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Palette.page.ignoresSafeArea(edges: .vertical))
        .tint(Palette.nightGreen)
        .overlay(alignment: .leading) {
            if still != nil || page.pasted != nil {
                Rectangle()
                    .fill(Palette.silver.opacity(0.35))
                    .frame(width: 1)
                    .frame(width: 16)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 1, coordinateSpace: .global)
                            .onChanged { value in
                                let start = wordsWidthAtDragStart ?? wordsWidth
                                wordsWidthAtDragStart = start
                                wordsWidth = min(
                                    max(start - value.translation.width, Self.narrowestWordsColumn),
                                    screen.width * 0.6)
                            }
                            .onEnded { _ in wordsWidthAtDragStart = nil }
                    )
                    .accessibilityLabel(Text("Words column edge", bundle: .module))
                    .accessibilityHint(
                        Text("Drag to make the column wider or narrower", bundle: .module))
            }
        }
    }
}
