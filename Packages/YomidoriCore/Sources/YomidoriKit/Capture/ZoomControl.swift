import Foundation

/// The way the zoom buttons reach whatever view is zooming, UIKit or SwiftUI.
@MainActor
final class ZoomControl {
    var zoom: ((CGFloat) -> Void)?

    func zoom(by factor: CGFloat) {
        zoom?(factor)
    }
}
