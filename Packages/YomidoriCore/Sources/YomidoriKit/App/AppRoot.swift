import SwiftUI

/// The root: the capture screen, and the place navigation will hang from.
public struct AppRoot: View {
    public init() {}

    public var body: some View {
        CaptureView()
    }
}
