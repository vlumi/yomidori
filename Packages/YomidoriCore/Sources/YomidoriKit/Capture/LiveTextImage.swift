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
    let selection: LiveTextSelection
    let zoomControl: ZoomControl

    func makeUIView(context: Context) -> ZoomingImageView {
        let view = ZoomingImageView(image: UIImage(cgImage: still.image))
        view.imageView.addInteraction(context.coordinator.interaction)
        view.interaction = context.coordinator.interaction
        zoomControl.zoom = { [weak view] factor in view?.zoom(by: factor) }
        return view
    }

    func updateUIView(_ uiView: ZoomingImageView, context: Context) {
        uiView.imageView.image = UIImage(cgImage: still.image)
        context.coordinator.interaction.analysis = analysis
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: selection)
    }

    static func dismantleUIView(_ uiView: ZoomingImageView, coordinator: Coordinator) {
        coordinator.stop()
    }

    @MainActor final class Coordinator {
        let interaction = ImageAnalysisInteraction()
        private let selection: LiveTextSelection
        private var timer: Timer?

        init(selection: LiveTextSelection) {
            self.selection = selection
            interaction.preferredInteractionTypes = .textSelection
            timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.poll() }
            }
        }

        private func poll() {
            let text = interaction.selectedText
            guard text != selection.text else { return }
            selection.text = text
            selection.range = interaction.selectedRanges.first
        }

        func stop() {
            timer?.invalidate()
            timer = nil
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

        func zoom(by factor: CGFloat) {
            let scale = min(max(zoomScale * factor, minimumZoomScale), maximumZoomScale)
            setZoomScale(scale, animated: true)
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            center()
            interaction?.setContentsRectNeedsUpdate()
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
