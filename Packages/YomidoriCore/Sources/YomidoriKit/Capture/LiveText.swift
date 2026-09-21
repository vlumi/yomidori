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

    static func analyze(_ still: Still) async throws -> ImageAnalysis {
        try await ImageAnalyzer().analyze(
            still.image, orientation: .up, configuration: ImageAnalyzer.Configuration([.text]))
    }
}
