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

    // MARK: The drawer's edge

    /// The camera at the thumb's side of the drawer's edge: another photo, or back to the
    /// camera from a pasted page.
    var drawerNear: some View {
        PageButton(
            symbol: "camera",
            label: still == nil
                ? Text("Back to the camera", bundle: .module)
                : Text("Take another photo", bundle: .module),
            action: retake)
    }

    /// The next page at the far side: wanted far less often than the camera.
    @ViewBuilder var drawerFar: some View {
        if still != nil {
            NextPageButton(
                canAddPage: currentTranscript != nil && pages.count + 1 < Self.pagesInASpread,
                addPage: addPage,
                moveNextPage: pages.count + 1 < Self.pagesInASpread ? nil : moveNextPage)
        }
    }

    /// What the app is at while a page is on its way to its words: the recognizers, then
    /// the reading of the words; nil once the words are there, or when there is no page.
    var busy: Text? {
        if taking { return Text("Taking the page…", bundle: .module) }
        if recognizing { return Text("Reading the page…", bundle: .module) }
        if currentTranscript != nil, page.reading == nil {
            return Text("Reading the words…", bundle: .module)
        }
        return nil
    }
}
