import SwiftUI

#if os(iOS)
import AVFoundation
import AVKit
import UIKit
#endif

#if os(iOS)

/// `access` is passed as a value so SwiftUI updates the view when it changes; a class
/// reference alone reads as unchanged. The volume buttons and the Camera Control press the
/// shutter from iOS 17.2, where the system hands capture apps those presses. A tap focuses
/// on the spot tapped.
struct CameraPreview: UIViewRepresentable {
    let camera: Camera
    let access: Camera.Access
    let shutter: () -> Void

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer?.videoGravity = .resizeAspect
        view.addGestureRecognizer(
            UIPinchGestureRecognizer(
                target: context.coordinator, action: #selector(Gestures.pinched)))
        view.addGestureRecognizer(
            UITapGestureRecognizer(target: context.coordinator, action: #selector(Gestures.tapped)))
        if #available(iOS 17.2, *) {
            let shutter = self.shutter
            view.addInteraction(
                AVCaptureEventInteraction { event in
                    if event.phase == .began { shutter() }
                })
        }
        return view
    }

    func makeCoordinator() -> Gestures {
        Gestures(camera: camera)
    }

    final class Gestures: NSObject {
        private let camera: Camera

        init(camera: Camera) {
            self.camera = camera
        }

        @objc func pinched(_ gesture: UIPinchGestureRecognizer) {
            camera.pinch(scale: gesture.scale, began: gesture.state == .began)
        }

        @objc func tapped(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view as? PreviewView, let layer = view.previewLayer else {
                return
            }
            camera.focus(
                at: layer.captureDevicePointConverted(fromLayerPoint: gesture.location(in: view)))
        }
    }

    /// The layer gets the session only once a camera is behind it.
    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer?.session = access == .ready ? camera.session : nil
    }

    final class PreviewView: UIView {
        override static var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var previewLayer: AVCaptureVideoPreviewLayer? { layer as? AVCaptureVideoPreviewLayer }
    }
}
#else
struct CameraPreview: View {
    let camera: Camera
    let access: Camera.Access
    let shutter: () -> Void

    var body: some View {
        Color.black
    }
}
#endif
