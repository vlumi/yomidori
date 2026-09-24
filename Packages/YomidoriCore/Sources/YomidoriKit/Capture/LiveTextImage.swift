import SwiftUI
import VisionKit
import YomidoriCore

#if os(iOS)
import UIKit
#endif

#if os(iOS)
struct LiveTextImage: UIViewRepresentable {
    let still: Still
    let analysis: ImageAnalysis?
    @ObservedObject var selection: LiveTextSelection
    let zoomControl: ZoomControl

    func makeUIView(context: Context) -> ZoomingImageView {
        let view = ZoomingImageView(image: UIImage(cgImage: still.image))
        view.imageView.addInteraction(context.coordinator.interaction)
        view.interaction = context.coordinator.interaction
        zoomControl.apply = { [weak view] fraction in view?.zoom(toFraction: fraction) }
        view.reportZoom = { [weak zoomControl] fraction in zoomControl?.report(fraction) }
        return view
    }

    func updateUIView(_ uiView: ZoomingImageView, context: Context) {
        if context.coordinator.stillID != still.id {
            context.coordinator.stillID = still.id
            uiView.imageView.image = UIImage(cgImage: still.image)
        }
        if context.coordinator.interaction.analysis !== analysis {
            context.coordinator.interaction.analysis = analysis
        }
        // While the page is read into words it takes no selection.
        uiView.imageView.isUserInteractionEnabled = !selection.looking
        if let analysis, let requested = selection.requested,
            let range = CharacterRange.of(requested, in: analysis.transcript),
            context.coordinator.interaction.selectedRanges != [range]
        {
            context.coordinator.interaction.selectedRanges = [range]
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: selection)
    }

    @MainActor final class Coordinator: NSObject, ImageAnalysisInteractionDelegate {
        let interaction = ImageAnalysisInteraction()
        var stillID: UUID?
        private let selection: LiveTextSelection

        init(selection: LiveTextSelection) {
            self.selection = selection
            super.init()
            interaction.preferredInteractionTypes = .textSelection
            interaction.delegate = self
        }

        func textSelectionDidChange(_ interaction: ImageAnalysisInteraction) {
            // Told during an update of the view (a selection set from elsewhere): recorded
            // after it, not within.
            DispatchQueue.main.async { [weak self] in self?.selectionChanged() }
        }

        private func selectionChanged() {
            let text = interaction.selectedText
            let range = interaction.selectedRanges.first.flatMap { range in
                interaction.analysis.flatMap { analysis -> Range<Int>? in
                    let transcript = analysis.transcript
                    // A selection outliving the analysis it came from: nothing to report.
                    guard range.lowerBound >= transcript.startIndex,
                        range.upperBound <= transcript.endIndex
                    else { return nil }
                    let start = transcript.distance(
                        from: transcript.startIndex, to: range.lowerBound)
                    return start..<(start + transcript[range].count)
                }
            }
            guard text != selection.text || range != selection.range else { return }
            selection.text = text
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

    /// The image view is exactly the fitted image, centered by insets, so Live Text's
    /// highlights have no letterbox to drift into; the highlights are told to re-measure
    /// whenever the layout or the zoom changes.
    final class ZoomingImageView: UIScrollView, UIScrollViewDelegate {
        let imageView: FittedImageView
        var interaction: ImageAnalysisInteraction?
        private var fittedImage: CGSize = .zero

        init(image: UIImage) {
            imageView = FittedImageView(image: image)
            super.init(frame: .zero)
            imageView.contentMode = .scaleAspectFit
            imageView.isUserInteractionEnabled = true
            addSubview(imageView)
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

        /// Fitted once per image; a later change of bounds, the drawer moving, keeps the
        /// zoom and the place on the page.
        override func layoutSubviews() {
            super.layoutSubviews()
            if let image = imageView.image, image.size != fittedImage, bounds.width > 0 {
                fittedImage = image.size
                fit(image.size)
            }
            center()
            interaction?.setContentsRectNeedsUpdate()
        }

        /// Opens filling the width, the top of the page at the top, where reading starts.
        private func fit(_ imageSize: CGSize) {
            let fitted = TextGeometry.fittedFrame(of: imageSize, in: bounds.size)
            zoomScale = 1
            imageView.frame = CGRect(origin: .zero, size: fitted.size)
            contentSize = fitted.size
            minimumZoomScale = 1
            zoomScale = fitted.width > 0 ? max(1, bounds.width / fitted.width) : 1
            contentOffset = .zero
        }

        private func center() {
            let dx = max(0, (bounds.width - contentSize.width) / 2)
            let dy = max(0, (bounds.height - contentSize.height) / 2)
            contentInset = UIEdgeInsets(top: dy, left: dx, bottom: dy, right: dx)
        }

        var reportZoom: ((Double) -> Void)?

        func zoom(toFraction fraction: Double) {
            setZoomScale(
                Zoom.scale(at: fraction, in: minimumZoomScale...maximumZoomScale), animated: false)
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            center()
            interaction?.setContentsRectNeedsUpdate()
            // Reported after the layout pass it may come from, not within it.
            let fraction = Zoom.fraction(of: zoomScale, in: minimumZoomScale...maximumZoomScale)
            DispatchQueue.main.async { [weak self] in self?.reportZoom?(fraction) }
        }
    }
}
#else
struct LiveTextImage: View {
    let still: Still
    let analysis: ImageAnalysis?
    let selection: LiveTextSelection
    let zoomControl: ZoomControl

    var body: some View {
        Image(decorative: still.image, scale: 1).resizable().scaledToFit()
    }
}
#endif
