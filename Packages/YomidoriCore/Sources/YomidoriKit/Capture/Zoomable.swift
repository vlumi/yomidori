import SwiftUI

/// Where a zoomed view stands: its scale and how far it has been dragged.
struct Zoom: Equatable {
    var scale: CGFloat = 1
    var offset: CGSize = .zero

    static let range: ClosedRange<CGFloat> = 1...6

    /// The offset kept so the content never leaves the view empty on a side.
    func clamped(in bounds: CGSize) -> Zoom {
        let slackX = bounds.width * (scale - 1) / 2
        let slackY = bounds.height * (scale - 1) / 2
        return Zoom(
            scale: scale,
            offset: CGSize(
                width: min(max(offset.width, -slackX), slackX),
                height: min(max(offset.height, -slackY), slackY)))
    }
}

/// Pinch to zoom and drag to pan the view this modifies, about its centre. A
/// no-op off iOS, where the test build has no gestures to give it.
struct Zoomable: ViewModifier {
    @Binding var zoom: Zoom
    let bounds: CGSize
    @State private var atStart = Zoom()

    func body(content: Content) -> some View {
        #if os(iOS)
        content
            .scaleEffect(zoom.scale)
            .offset(zoom.offset)
            .gesture(pinch.simultaneously(with: drag))
        #else
        content
        #endif
    }

    private var pinch: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                var next = zoom
                next.scale = min(
                    max(atStart.scale * value, Zoom.range.lowerBound), Zoom.range.upperBound)
                zoom = next.clamped(in: bounds)
            }
            .onEnded { _ in atStart = zoom }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                var next = zoom
                next.offset = CGSize(
                    width: atStart.offset.width + value.translation.width,
                    height: atStart.offset.height + value.translation.height)
                zoom = next.clamped(in: bounds)
            }
            .onEnded { _ in atStart = zoom }
    }
}

extension View {
    func zoomable(_ zoom: Binding<Zoom>, in bounds: CGSize) -> some View {
        modifier(Zoomable(zoom: zoom, bounds: bounds))
    }
}
