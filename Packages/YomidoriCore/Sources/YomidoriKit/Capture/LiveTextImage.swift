import SwiftUI
import VisionKit
import YomidoriCore

#if os(iOS)
import UIKit
#endif

#if os(iOS)
/// Live Text over the spread's pages, laid out as one sheet and zoomed as one; each page its
/// own photo with its own interaction, so each is selected in and read on its own. A selection
/// is reported with the page it is on; one made on a page clears the other's.
struct LiveTextImage: UIViewRepresentable {
    struct Sheet {
        let still: Still
        let analysis: ImageAnalysis?
    }

    let sheets: [Sheet]
    let side: SpreadLayout.Side
    @ObservedObject var selection: LiveTextSelection
    let zoomControl: ZoomControl

    func makeUIView(context: Context) -> ZoomingImageView {
        let view = ZoomingImageView()
        zoomControl.apply = { [weak view] fraction in view?.zoom(toFraction: fraction) }
        view.reportZoom = { [weak zoomControl] fraction in zoomControl?.report(fraction) }
        return view
    }

    func updateUIView(_ uiView: ZoomingImageView, context: Context) {
        let coordinator = context.coordinator
        let key = sheets.map(\.still.id.uuidString).joined(separator: " ") + " \(side)"
        if coordinator.layoutKey != key {
            coordinator.layoutKey = key
            uiView.show(sheets.map { UIImage(cgImage: $0.still.preview) }, nextOn: side)
            coordinator.attach(to: uiView.imageViews)
        }
        for (index, sheet) in sheets.enumerated() where index < coordinator.links.count {
            let interaction = coordinator.links[index].interaction
            if interaction.analysis !== sheet.analysis {
                interaction.analysis = sheet.analysis
                let selection = self.selection
                afterViewUpdate {
                    selection.pageTexts[index] =
                        interaction.analysis == nil ? nil : interaction.text
                }
            }
            // While the page is read into words it takes no new selection, but it still zooms
            // and pans; a selection made meanwhile is taken up once the reading is done.
            let types: ImageAnalysisInteraction.InteractionTypes =
                selection.looking ? [] : .textSelection
            if interaction.preferredInteractionTypes != types {
                interaction.preferredInteractionTypes = types
            }
            if sheet.analysis != nil, let requested = selection.requested,
                selection.requestedPage == index,
                let range = CharacterRange.of(requested, in: interaction.text),
                interaction.selectedRanges != [range]
            {
                interaction.selectedRanges = [range]
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: selection)
    }

    /// One page's interaction, telling the coordinator which page a selection is on.
    @MainActor final class PageLink: NSObject, ImageAnalysisInteractionDelegate {
        let interaction = ImageAnalysisInteraction()
        let index: Int
        weak var coordinator: Coordinator?

        init(index: Int) {
            self.index = index
            super.init()
            interaction.preferredInteractionTypes = .textSelection
            interaction.delegate = self
        }

        func textSelectionDidChange(_ interaction: ImageAnalysisInteraction) {
            afterViewUpdate { [weak self] in
                guard let self else { return }
                self.coordinator?.selectionChanged(on: self.index)
            }
        }
    }

    @MainActor final class Coordinator {
        private(set) var links: [PageLink] = []
        var layoutKey: String?
        private let selection: LiveTextSelection

        init(selection: LiveTextSelection) {
            self.selection = selection
        }

        /// One interaction per page's image view, made anew when the pages change.
        func attach(to imageViews: [UIImageView]) {
            for link in links { link.interaction.view?.removeInteraction(link.interaction) }
            links = imageViews.indices.map { index in
                let link = PageLink(index: index)
                link.coordinator = self
                imageViews[index].addInteraction(link.interaction)
                return link
            }
        }

        func selectionChanged(on index: Int) {
            guard links.indices.contains(index) else { return }
            let interaction = links[index].interaction
            // The ranges index the interaction's own text, not the analysis's transcript.
            let page = interaction.text
            let range = interaction.selectedRanges.first.flatMap { range -> Range<Int>? in
                // A selection outliving the text it came from: nothing to report.
                guard interaction.analysis != nil else { return nil }
                return CharacterRange.offsets(of: range, in: page)
            }
            // A page with nothing selected says nothing of the other page's selection.
            guard range != nil || selection.rangePage == index else { return }
            if range != nil {
                // One selection at a time: the other page's goes.
                for other in links where other.index != index {
                    if !other.interaction.selectedRanges.isEmpty {
                        other.interaction.selectedRanges = []
                    }
                }
            }
            let text = interaction.selectedText
            guard
                text != selection.text || range != selection.range
                    || index != selection.rangePage
            else { return }
            selection.text = text
            selection.rangePage = index
            selection.range = range
        }
    }

    /// UIImageView's intrinsic size is the image's pixel size, and SwiftUI would lay a
    /// 4000-point still out at that size; this one has none.
    final class FittedImageView: UIImageView {
        override var intrinsicContentSize: CGSize {
            CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
        }
    }

    /// The pages in one container, each image view exactly its fitted page, the container
    /// centered by insets, so Live Text's highlights have no letterbox to drift into; they
    /// are told to re-measure whenever the layout or the zoom changes.
    final class ZoomingImageView: UIScrollView, UIScrollViewDelegate {
        private let container = UIView()
        private(set) var imageViews: [FittedImageView] = []
        private var side: SpreadLayout.Side = .left
        private var fittedFor: [CGSize] = []

        init() {
            super.init(frame: .zero)
            addSubview(container)
            delegate = self
            maximumZoomScale = Zoom.range.upperBound
            showsHorizontalScrollIndicator = false
            showsVerticalScrollIndicator = false
            bouncesZoom = true
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("not used")
        }

        func show(_ images: [UIImage], nextOn side: SpreadLayout.Side) {
            imageViews.forEach { $0.removeFromSuperview() }
            imageViews = images.map { image in
                let view = FittedImageView(image: image)
                view.contentMode = .scaleAspectFit
                view.isUserInteractionEnabled = true
                container.addSubview(view)
                return view
            }
            self.side = side
            fittedFor = []
            setNeedsLayout()
        }

        /// Fitted once per set of pages; a later change of bounds, the drawer moving, keeps
        /// the zoom and the place on the page.
        override func layoutSubviews() {
            super.layoutSubviews()
            let sizes = imageViews.compactMap(\.image?.size)
            if !sizes.isEmpty, sizes != fittedFor, bounds.width > 0 {
                fittedFor = sizes
                fit(sizes)
            }
            center()
            updateHighlights()
        }

        /// Opens filling the width, the top of the page at the top, where reading starts.
        private func fit(_ sizes: [CGSize]) {
            let (sheet, frames) = SpreadLayout.arrange(sizes, nextOn: side)
            let fitted = TextGeometry.fittedFrame(of: sheet, in: bounds.size)
            guard sheet.width > 0 else { return }
            let scale = fitted.width / sheet.width
            zoomScale = 1
            container.frame = CGRect(origin: .zero, size: fitted.size)
            for (view, frame) in zip(imageViews, frames) {
                view.frame = CGRect(
                    x: frame.minX * scale, y: frame.minY * scale, width: frame.width * scale,
                    height: frame.height * scale)
            }
            contentSize = fitted.size
            minimumZoomScale = 1
            zoomScale = fitted.width > 0 ? max(1, bounds.width / fitted.width) : 1
            // At rest: the page's corner at the view's, or centered where it is smaller.
            centering = .zero
            contentOffset = .zero
            center()
        }

        /// How far the content is pushed in to stand centered, when smaller than the view.
        private var centering = CGSize.zero

        /// Centered when smaller than the view, and a margin beyond every edge either way, so
        /// a word at the page's edge scrolls out from under the controls that stand there.
        /// The page keeps its place on the screen as the centering changes with the zoom.
        private func center() {
            let margin = Zoom.margin(in: bounds.size)
            let dx = max(0, (bounds.width - contentSize.width) / 2)
            let dy = max(0, (bounds.height - contentSize.height) / 2)
            let wanted = UIEdgeInsets(
                top: dy + margin, left: dx + margin, bottom: dy + margin, right: dx + margin)
            guard contentInset != wanted else { return }
            let offset = CGPoint(
                x: contentOffset.x - (dx - centering.width),
                y: contentOffset.y - (dy - centering.height))
            centering = CGSize(width: dx, height: dy)
            contentInset = wanted
            contentOffset = offset
        }

        private func updateHighlights() {
            for view in imageViews {
                for case let interaction as ImageAnalysisInteraction in view.interactions {
                    interaction.setContentsRectNeedsUpdate()
                }
            }
        }

        var reportZoom: ((Double) -> Void)?

        func zoom(toFraction fraction: Double) {
            setZoomScale(
                Zoom.scale(at: fraction, in: minimumZoomScale...maximumZoomScale), animated: false)
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            container
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            center()
            updateHighlights()
            let fraction = Zoom.fraction(of: zoomScale, in: minimumZoomScale...maximumZoomScale)
            afterViewUpdate { [weak self] in self?.reportZoom?(fraction) }
        }
    }
}
#else
struct LiveTextImage: View {
    struct Sheet {
        let still: Still
        let analysis: ImageAnalysis?
    }

    let sheets: [Sheet]
    let side: SpreadLayout.Side
    let selection: LiveTextSelection
    let zoomControl: ZoomControl

    var body: some View {
        if let last = sheets.last {
            Image(decorative: last.still.preview, scale: 1).resizable().scaledToFit()
        }
    }
}
#endif
