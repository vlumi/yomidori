import AVFoundation
import CoreGraphics
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

    func captureOutput(
        _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pending, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        self.pending = nil
        pending.resume(returning: Self.image(from: buffer))
    }

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
#endif
