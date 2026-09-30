import SwiftUI
import YomidoriCore

struct Zoomable: ViewModifier {
    @Binding var zoom: Zoom
    let bounds: CGSize
    /// Where the zoom stood as each gesture began, taken at its first change: a zoom set
    /// from elsewhere meanwhile (a double tap back, the slider, the opening fill) is where
    /// the next gesture starts from, not where the last one ended.
    @State private var pinchStart: Zoom?
    @State private var dragStart: Zoom?

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
                let start = pinchStart ?? zoom
                pinchStart = start
                zoom = start.stepped(by: value, in: bounds)
            }
            .onEnded { _ in pinchStart = nil }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                let start = dragStart ?? zoom
                dragStart = start
                // At the scale of now, should a pinch be going on at the same time.
                zoom = Zoom(scale: zoom.scale, offset: start.offset)
                    .panned(by: value.translation, in: bounds)
            }
            .onEnded { _ in dragStart = nil }
    }
}

extension View {
    func zoomable(_ zoom: Binding<Zoom>, in bounds: CGSize) -> some View {
        modifier(Zoomable(zoom: zoom, bounds: bounds))
    }
}
