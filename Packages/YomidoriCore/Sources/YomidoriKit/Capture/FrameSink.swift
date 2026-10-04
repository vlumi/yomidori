import AVFoundation
import CoreGraphics
import CoreImage
import Foundation

#if os(iOS)
/// Hands one frame to whoever asked for the next; every other frame is dropped. Touched on
/// the camera queue only, which is what makes it safe to send.
final class FrameSink: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate,
    @unchecked Sendable
{
    private var pending: CheckedContinuation<CGImage?, Never>?

    func request(_ continuation: CheckedContinuation<CGImage?, Never>) {
        pending?.resume(returning: nil)
        pending = continuation
    }

    func cancel() {
        pending?.resume(returning: nil)
        pending = nil
    }

    func captureOutput(
        _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pending, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        self.pending = nil
        pending.resume(returning: Self.image(from: buffer))
    }

    /// One context for the one frame taken per page; nothing cached between frames.
    private static let context = CIContext(options: [.cacheIntermediates: false])

    /// The frame as an RGB image of its own, converted from the camera's planar format and
    /// copied out of the buffer, which the camera takes back for the next frame.
    private static func image(from buffer: CVPixelBuffer) -> CGImage? {
        let frame = CIImage(cvPixelBuffer: buffer)
        return context.createCGImage(frame, from: frame.extent)
    }
}
#endif
