import SwiftUI
import VisionKit

#if os(iOS)
import UIKit
#endif

/// VisionKit's Live Text: reads vertical Japanese where Vision does not, but gives no positions.
enum LiveText {
    static var isSupported: Bool {
        ImageAnalyzer.isSupported
    }

    /// Of the picture as shown, not the full frame: the overlay draws its selection against
    /// the image it analyzed, and analyzed at one size and shown at another the highlight
    /// landed a tenth off. Vision's boxes are normalized and read the full frame.
    static func analyze(_ still: Still) async throws -> ImageAnalysis {
        try await ImageAnalyzer().analyze(
            still.preview, orientation: .up, configuration: ImageAnalyzer.Configuration([.text]))
    }
}
