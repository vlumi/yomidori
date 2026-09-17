import Foundation
import SwiftUI

#if os(iOS)
import AVFoundation
import UIKit
#endif

/// The back camera as a source of stills: a live preview that only frames, and a
/// shutter that keeps the next frame of the stream. It is a frame grab, not a
/// photo capture: nothing is written to the library, and there is no shutter
/// sound (mandatory for photo capture in Japan, where the app is read). Off iOS
/// (the macOS test build, the simulator) there is no camera, and the screen
/// offers the photo picker instead.
final class Camera: ObservableObject {
    enum Access {
        case undetermined
        case ready
        case denied
        case unavailable
    }

    @Published private(set) var access: Access = .undetermined

    #if os(iOS)
    let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let frames = FrameSink()
    private let queue = DispatchQueue(label: "fi.misaki.yomidori.camera")
    private var configured = false
    #endif

    /// Asks for camera access on first use, then starts the preview.
    func start() {
        #if os(iOS)
        AVCaptureDevice.requestAccess(for: .video) { [self] granted in
            guard granted else { return set(.denied) }
            queue.async { [self] in
                if !configured {
                    configured = true
                    guard configure() else { return set(.unavailable) }
                }
                session.startRunning()
                set(.ready)
            }
        }
        #else
        access = .unavailable
        #endif
    }

    func stop() {
        #if os(iOS)
        queue.async { [self] in session.stopRunning() }
        #endif
    }

    /// The next frame of the stream, as the preview shows it. Nil if none arrives.
    func takeStill() async -> Still? {
        #if os(iOS)
        let frames = frames
        let image: CGImage? = await withCheckedContinuation { continuation in
            queue.async { frames.request(continuation) }
        }
        return image.map(Still.init(image:))
        #else
        return nil
        #endif
    }

    private func set(_ access: Access) {
        DispatchQueue.main.async { self.access = access }
    }

    #if os(iOS)
    private func configure() -> Bool {
        guard
            let device = AVCaptureDevice.default(
                .builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device)
        else { return false }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(frames, queue: queue)
        guard session.canAddInput(input), session.canAddOutput(output) else { return false }
        session.addInput(input)
        session.addOutput(output)
        output.connection(with: .video)?.videoOrientation = .portrait
        return true
    }
    #endif
}

#if os(iOS)
/// Receives the stream and hands one frame to whoever asked for the next one;
/// every other frame is dropped. Touched on the camera queue only, which is
/// what makes it safe to send.
private final class FrameSink: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate,
    @unchecked Sendable
{
    private var pending: CheckedContinuation<CGImage?, Never>?

    func request(_ continuation: CheckedContinuation<CGImage?, Never>) {
        pending?.resume(returning: nil)
        pending = continuation
    }

    func captureOutput(
        _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pending, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        self.pending = nil
        pending.resume(returning: Self.image(from: buffer))
    }

    /// A BGRA pixel buffer copied into a CGImage, with plain CoreGraphics.
    private static func image(from buffer: CVPixelBuffer) -> CGImage? {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let context = CGContext(
            data: base, width: CVPixelBufferGetWidth(buffer),
            height: CVPixelBufferGetHeight(buffer),
            bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue
                | CGImageAlphaInfo.premultipliedFirst.rawValue)
        return context?.makeImage()
    }
}

/// The live camera frame, letterboxed so what is seen is what the still holds.
/// `access` is passed as a value so SwiftUI updates the view when it changes;
/// a class reference alone reads as unchanged and the update is skipped.
struct CameraPreview: UIViewRepresentable {
    let camera: Camera
    let access: Camera.Access

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer?.videoGravity = .resizeAspect
        return view
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

    var body: some View {
        Color.black
    }
}
#endif
