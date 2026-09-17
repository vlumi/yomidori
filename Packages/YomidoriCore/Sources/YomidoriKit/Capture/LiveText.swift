import SwiftUI
import VisionKit

#if os(iOS)
import UIKit
#endif

/// The other recognizer the OS ships: the Live Text engine behind the Camera and
/// Photos apps, which reads vertical Japanese where Vision's request does not. It
/// returns the page as a transcript and, on iOS, its own selection UI over the
/// image, but no positions, so it is measured here beside Vision, not chosen yet.
enum LiveText {
    static var isSupported: Bool {
        ImageAnalyzer.isSupported
    }

    static func analyze(_ still: Still) async throws -> ImageAnalysis {
        try await ImageAnalyzer().analyze(
            still.image, orientation: .up, configuration: ImageAnalyzer.Configuration([.text]))
    }
}

#if os(iOS)
/// The still with Live Text's own selection over it: tap, drag or double-tap the
/// words as in Photos, to see how the engine segments what it read.
struct LiveTextImage: UIViewRepresentable {
    let still: Still
    let analysis: ImageAnalysis?

    func makeUIView(context: Context) -> FittedImageView {
        let view = FittedImageView(image: UIImage(cgImage: still.image))
        view.contentMode = .scaleAspectFit
        view.isUserInteractionEnabled = true
        view.addInteraction(context.coordinator)
        return view
    }

    func updateUIView(_ uiView: FittedImageView, context: Context) {
        uiView.image = UIImage(cgImage: still.image)
        context.coordinator.analysis = analysis
    }

    /// An image view with no natural size of its own. UIImageView reports the
    /// image's pixel size, and SwiftUI would lay a 4000-point still out at that
    /// size, over everything; this one takes whatever the screen offers.
    final class FittedImageView: UIImageView {
        override var intrinsicContentSize: CGSize {
            CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
        }
    }

    func makeCoordinator() -> ImageAnalysisInteraction {
        let interaction = ImageAnalysisInteraction()
        interaction.preferredInteractionTypes = .textSelection
        return interaction
    }
}
#else
struct LiveTextImage: View {
    let still: Still
    let analysis: ImageAnalysis?

    var body: some View {
        Image(decorative: still.image, scale: 1).resizable().scaledToFit()
    }
}
#endif
