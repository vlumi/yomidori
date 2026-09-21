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
