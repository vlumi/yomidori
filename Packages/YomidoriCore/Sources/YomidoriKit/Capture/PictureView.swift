import SwiftUI
import VisionKit
import YomidoriCore

#if os(macOS)
import AppKit

/// A picture of a page on the Mac, with Live Text's own selection over it, as the phone's
/// `LiveTextImage` has: the picture fitted to the pane, scrolled and magnified by the
/// trackpad, the overlay view tracking the image view. A selection is reported as
/// characters of the overlay's own text, which is what its ranges index.
struct PictureView: NSViewRepresentable {
    let still: Still
    let analysis: ImageAnalysis?
    @ObservedObject var selection: LiveTextSelection
    /// The zoom last asked of the picture, by number so the same ask twice is two.
    var zoom: ZoomAsk?

    /// What the page bar's Zoom menu asks: the trackpad does the rest.
    struct ZoomAsk: Equatable {
        let id: Int
        let kind: ZoomKind
    }

    enum ZoomKind {
        case fit, actual, closer, further
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        scroll.allowsMagnification = true
        scroll.minMagnification = 0.25
        scroll.maxMagnification = 6
        scroll.drawsBackground = true
        scroll.backgroundColor = NSColor(Palette.page)
        let container = FittingImageView()
        container.overlay.delegate = context.coordinator
        container.overlay.preferredInteractionTypes = .textSelection
        scroll.documentView = container
        context.coordinator.container = container
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let container = context.coordinator.container else { return }
        if container.stillID != still.id {
            container.stillID = still.id
            // The picture Live Text analyzed, so its selection lands where it should.
            container.imageView.image = NSImage(
                cgImage: still.preview,
                size: NSSize(width: still.preview.width, height: still.preview.height)
            )
            container.fit(in: scroll)
        }
        if let zoom, zoom.id != context.coordinator.zoomApplied {
            context.coordinator.zoomApplied = zoom.id
            container.zoom(zoom.kind, in: scroll)
        }
        let overlay = container.overlay
        if overlay.analysis !== analysis {
            overlay.analysis = analysis
            let selection = self.selection
            afterViewUpdate {
                selection.pageTexts[0] = overlay.analysis == nil ? nil : overlay.text
            }
        }
        let types: ImageAnalysisOverlayView.InteractionTypes =
            selection.looking ? [] : .textSelection
        if overlay.preferredInteractionTypes != types {
            overlay.preferredInteractionTypes = types
        }
        if analysis != nil, let requested = selection.requested, selection.requestedPage == 0,
            let range = CharacterRange.of(requested, in: overlay.text),
            overlay.selectedRanges != [range]
        {
            overlay.selectedRanges = [range]
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: selection)
    }

    /// The image view with the overlay over it, sized to the picture and fitted to the pane
    /// once; the scroll view's magnification does the rest.
    final class FittingImageView: NSView {
        let imageView = NSImageView()
        let overlay = ImageAnalysisOverlayView()
        var stillID: UUID?

        override init(frame: NSRect) {
            super.init(frame: frame)
            imageView.imageScaling = .scaleAxesIndependently
            addSubview(imageView)
            overlay.trackingImageView = imageView
            addSubview(overlay)
        }

        required init?(coder: NSCoder) { nil }

        override func layout() {
            super.layout()
            imageView.frame = bounds
            overlay.frame = bounds
        }

        /// The picture at its own pixel size, magnified to fill the pane's width, the top in
        /// view, where reading starts.
        func fit(in scroll: NSScrollView) {
            guard let image = imageView.image, image.size.width > 0 else { return }
            frame = NSRect(origin: .zero, size: image.size)
            let width = scroll.contentSize.width
            let magnification = min(
                max(width / image.size.width, scroll.minMagnification), scroll.maxMagnification)
            scroll.magnification = magnification
            scroll.contentView.scroll(to: NSPoint(x: 0, y: image.size.height))
            scroll.reflectScrolledClipView(scroll.contentView)
        }

        /// A step of zoom about the middle of what is in view, or back to the fit or the
        /// pixels.
        func zoom(_ kind: ZoomKind, in scroll: NSScrollView) {
            let visible = scroll.contentView.bounds
            let middle = NSPoint(x: visible.midX, y: visible.midY)
            switch kind {
            case .fit: fit(in: scroll)
            case .actual: scroll.setMagnification(1, centeredAt: middle)
            case .closer: scroll.setMagnification(scroll.magnification * 1.25, centeredAt: middle)
            case .further: scroll.setMagnification(scroll.magnification / 1.25, centeredAt: middle)
            }
        }
    }

    @MainActor final class Coordinator: NSObject, ImageAnalysisOverlayViewDelegate {
        weak var container: FittingImageView?
        var zoomApplied = 0
        private let selection: LiveTextSelection

        init(selection: LiveTextSelection) {
            self.selection = selection
        }

        func textSelectionDidChange(_ overlayView: ImageAnalysisOverlayView) {
            afterViewUpdate { [weak self] in self?.report(overlayView) }
        }

        private func report(_ overlay: ImageAnalysisOverlayView) {
            let page = overlay.text
            let range = overlay.selectedRanges.first.flatMap { range -> Range<Int>? in
                guard overlay.analysis != nil else { return nil }
                return CharacterRange.offsets(of: range, in: page)
            }
            let text = overlay.selectedText
            guard text != selection.text || range != selection.range || selection.rangePage != 0
            else { return }
            selection.text = text
            selection.rangePage = 0
            selection.range = range
        }
    }
}
#endif
