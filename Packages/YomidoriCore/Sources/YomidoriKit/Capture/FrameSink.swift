import AVFoundation
import CoreGraphics
import CoreImage
import Foundation
import os

#if os(iOS)
/// Hands one frame to whoever asked for the next, as a still — upright, with the copy the
/// screen shows — and every other frame is dropped. Touched on the camera queue only, which
/// is what makes it safe to send.
final class FrameSink: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate,
    @unchecked Sendable
{
    private struct Request {
        let ticket: Int
        let continuation: CheckedContinuation<Still?, Never>
        let turn: CGFloat
    }

    private var pending: Request?
    private var tickets = 0

    /// `turn` is how far clockwise the frame is to be turned to stand upright. The ticket
    /// names this request, for a timeout to give up on it and no later one.
    @discardableResult
    func request(_ continuation: CheckedContinuation<Still?, Never>, turn: CGFloat) -> Int {
        pending?.continuation.resume(returning: nil)
        tickets += 1
        pending = Request(ticket: tickets, continuation: continuation, turn: turn)
        return tickets
    }

    /// The request still waiting is answered with nothing; with a ticket, only that request.
    func cancel(ticket: Int? = nil) {
        guard let pending, ticket == nil || ticket == pending.ticket else { return }
        pending.continuation.resume(returning: nil)
        self.pending = nil
    }

    func captureOutput(
        _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pending, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        self.pending = nil
        let started = ContinuousClock.now
        let still = Self.still(from: buffer, turn: pending.turn)
        Self.log.info("still made in \(ContinuousClock.now - started)")
        pending.continuation.resume(returning: still)
    }

    private static let log = Logger(subsystem: "fi.misaki.yomidori", category: "camera")

    /// One context for the one frame taken per page; nothing cached between frames.
    private static let context = CIContext(options: [.cacheIntermediates: false])

    /// The frame as a still of its own, copied out of the buffer, which the camera takes
    /// back for the next frame: converted from the camera's planar format and turned
    /// upright in one pass, and drawn down to the screen's size in another over the same
    /// image — not turned and scaled again as 48-megapixel bitmaps afterwards, which was
    /// seconds of nothing on the screen after the shutter.
    private static func still(from buffer: CVPixelBuffer, turn: CGFloat) -> Still? {
        let frame = CIImage(cvPixelBuffer: buffer).oriented(orientation(turning: turn))
        guard let image = context.createCGImage(frame, from: frame.extent) else { return nil }
        let longest = max(frame.extent.width, frame.extent.height)
        let scale = min(1, CGFloat(Still.previewSide) / longest)
        guard scale < 1 else { return Still(image: image, preview: image) }
        let small = frame.applyingFilter(
            "CILanczosScaleTransform",
            parameters: [kCIInputScaleKey: scale, kCIInputAspectRatioKey: 1])
        guard let preview = context.createCGImage(small, from: small.extent) else { return nil }
        return Still(image: image, preview: preview)
    }

    /// The EXIF orientation that stands for a clockwise turn by `degrees`, rounded to a
    /// quarter.
    private static func orientation(turning degrees: CGFloat) -> CGImagePropertyOrientation {
        switch ((Int((degrees / 90).rounded()) % 4) + 4) % 4 {
        case 1: return .right
        case 2: return .down
        case 3: return .left
        default: return .up
        }
    }
}
#endif
