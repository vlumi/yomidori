import Foundation
import SwiftUI

#if os(iOS)
import AVFoundation
import AVKit
import UIKit
#endif

/// A frame grab, not a photo capture: nothing is written to the library and there is no
/// shutter sound (mandatory for photo capture in Japan). Off iOS there is no camera.
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
    private var device: AVCaptureDevice?
    private var rotation: AVCaptureDevice.RotationCoordinator?
    private var rotationObservation: NSKeyValueObservation?
    private var zoomRange: ClosedRange<CGFloat> = 1...1
    private var zoomAtPinchStart: CGFloat = 1
    #endif

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

    func takeStill() async -> Still? {
        #if os(iOS)
        let frames = frames
        output.connection(with: .video)?.videoRotationAngle =
            rotation?.videoRotationAngleForHorizonLevelCapture ?? 90
        let image: CGImage? = await withCheckedContinuation { continuation in
            queue.async { frames.request(continuation) }
        }
        return image.map(Still.init(image:))
        #else
        return nil
        #endif
    }

    /// `scale` is relative to where the pinch began.
    func pinch(scale: CGFloat, began: Bool) {
        #if os(iOS)
        queue.async { [self] in
            guard let device, (try? device.lockForConfiguration()) != nil else { return }
            defer { device.unlockForConfiguration() }
            if began { zoomAtPinchStart = device.videoZoomFactor }
            device.videoZoomFactor = min(
                max(zoomAtPinchStart * scale, zoomRange.lowerBound), zoomRange.upperBound)
        }
        #endif
    }

    #if os(iOS)
    /// The preview follows the phone's orientation, and a still is taken the way the phone
    /// is held; the coordinator says by how much to turn each. Called once the layer shows.
    func attach(_ layer: AVCaptureVideoPreviewLayer) {
        guard rotation == nil, let device else { return }
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: layer)
        rotation = coordinator
        rotationObservation = coordinator.observe(
            \.videoRotationAngleForHorizonLevelPreview, options: [.initial, .new]
        ) { [weak layer] coordinator, _ in
            layer?.connection?.videoRotationAngle =
                coordinator.videoRotationAngleForHorizonLevelPreview
        }
    }
    #endif

    /// `point` in the device's own coordinates, as the preview layer converts a tap.
    func focus(at point: CGPoint) {
        #if os(iOS)
        queue.async { [self] in
            guard let device, device.isFocusPointOfInterestSupported,
                (try? device.lockForConfiguration()) != nil
            else { return }
            defer { device.unlockForConfiguration() }
            device.focusPointOfInterest = point
            device.focusMode = .autoFocus
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
            }
            device.isSubjectAreaChangeMonitoringEnabled = true
        }
        #endif
    }

    private func set(_ access: Access) {
        DispatchQueue.main.async { self.access = access }
    }

    #if os(iOS)
    /// One virtual device where the phone has several, so a close page goes to the ultra-wide
    /// (macro) and a pinch past the wide's reach to the telephoto, both optical.
    private func configure() -> Bool {
        let kinds: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera, .builtInDualWideCamera, .builtInWideAngleCamera,
        ]
        guard
            let device = kinds.lazy
                .compactMap({ AVCaptureDevice.default($0, for: .video, position: .back) }).first,
            let input = try? AVCaptureDeviceInput(device: device)
        else { return false }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.alwaysDiscardsLateVideoFrames = true
        // With the photo preset the output delivers preview-sized frames by default,
        // about a megapixel; the still wants the sensor's full frame.
        output.automaticallyConfiguresOutputBufferDimensions = false
        output.deliversPreviewSizedOutputBuffers = false
        output.setSampleBufferDelegate(frames, queue: queue)
        guard session.canAddInput(input), session.canAddOutput(output) else { return false }
        session.addInput(input)
        session.addOutput(output)
        output.connection(with: .video)?.videoRotationAngle = 90
        self.device = device
        focusNear(device)
        NotificationCenter.default.addObserver(
            self, selector: #selector(subjectAreaChanged),
            name: AVCaptureDevice.subjectAreaDidChangeNotification,
            object: device)
        return true
    }

    /// The page moved after a tap to focus: back to following it.
    @objc private func subjectAreaChanged() {
        queue.async { [self] in
            guard let device, (try? device.lockForConfiguration()) != nil else { return }
            defer { device.unlockForConfiguration() }
            device.isSubjectAreaChangeMonitoringEnabled = false
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
        }
    }

    /// On a virtual device zoom 1 is the ultra-wide, so start at the wide camera's own framing;
    /// keep the autofocus in the near range.
    private func focusNear(_ device: AVCaptureDevice) {
        guard (try? device.lockForConfiguration()) != nil else { return }
        defer { device.unlockForConfiguration() }
        let wide =
            device.virtualDeviceSwitchOverVideoZoomFactors.first.map { CGFloat(truncating: $0) }
            ?? 1
        zoomRange = wide...min(wide * 5, device.maxAvailableVideoZoomFactor)
        device.videoZoomFactor = wide
        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
        }
        if device.isAutoFocusRangeRestrictionSupported {
            device.autoFocusRangeRestriction = .near
        }
    }
    #endif
}
