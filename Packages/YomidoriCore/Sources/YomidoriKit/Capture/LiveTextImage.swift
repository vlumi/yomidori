import SwiftUI
import VisionKit

#if os(iOS)
import UIKit
#endif

#if os(iOS)
/// The still with Live Text's own selection over it, in a scroll view that pinches
/// to zoom as Photos does: tap, drag or double-tap the words to see how the engine
/// segments what it read.
struct LiveTextImage: UIViewRepresentable {
    let still: Still
    let analysis: ImageAnalysis?
    let selection: LiveTextSelection

    func makeUIView(context: Context) -> ZoomingImageView {
        let view = ZoomingImageView(image: UIImage(cgImage: still.image))
        view.imageView.addInteraction(context.coordinator.interaction)
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

        /// The selection is readable from iOS 17; on iOS 16 the strip below stays the way.
        private func poll() {
            guard #available(iOS 17, *) else { return }
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

    /// An image view with no natural size of its own. UIImageView reports the
    /// image's pixel size, and SwiftUI would lay a 4000-point still out at that
    /// size, over everything; this one takes whatever the screen offers.
    final class FittedImageView: UIImageView {
        override var intrinsicContentSize: CGSize {
            CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
        }
    }

    /// A scroll view whose only content is the image, filling it and zooming it.
    final class ZoomingImageView: UIScrollView, UIScrollViewDelegate {
        let imageView: FittedImageView

        init(image: UIImage) {
            imageView = FittedImageView(image: image)
            super.init(frame: .zero)
            imageView.contentMode = .scaleAspectFit
            imageView.isUserInteractionEnabled = true
            addSubview(imageView)
            delegate = self
            minimumZoomScale = 1
            maximumZoomScale = 6
            showsHorizontalScrollIndicator = false
            showsVerticalScrollIndicator = false
            bouncesZoom = true
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("not used")
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            if zoomScale == 1 {
                imageView.frame = bounds
                contentSize = bounds.size
            }
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }
    }
}
#else
struct LiveTextImage: View {
    let still: Still
    let analysis: ImageAnalysis?
    let selection: LiveTextSelection

    var body: some View {
        Image(decorative: still.image, scale: 1).resizable().scaledToFit()
    }
}
#endif
