import Foundation

/// The zoom slider's link to whichever view is zooming, UIKit's or SwiftUI's: the slider sets
/// a fraction of the view's range, and the view reports its own when a pinch changes it.
@MainActor
final class ZoomControl: ObservableObject {
    @Published private(set) var fraction: Double = 0
    var apply: ((Double) -> Void)?

    func set(_ fraction: Double) {
        self.fraction = fraction
        apply?(fraction)
    }

    func report(_ fraction: Double) {
        if abs(fraction - self.fraction) > 0.001 { self.fraction = fraction }
    }
}
