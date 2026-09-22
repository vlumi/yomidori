import SwiftUI
import YomidoriCore

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
