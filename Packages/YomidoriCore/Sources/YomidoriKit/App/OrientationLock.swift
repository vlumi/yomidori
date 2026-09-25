import SwiftUI

#if os(iOS)
import UIKit

/// The Read tab stays upright on a phone, as the Camera app does: the controls keep to the
/// phone's bottom edge and only their icons turn (`turnsWithPhone`). A still is still taken
/// the way the phone is held. An iPad turns as it likes.
@MainActor
public enum OrientationLock {
    /// What the app delegate reports to UIKit.
    public private(set) static var mask: UIInterfaceOrientationMask = .all

    static var isLocked: Bool { mask == .portrait }

    static func portrait(_ locked: Bool) {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        let wanted: UIInterfaceOrientationMask = locked ? .portrait : .all
        guard wanted != mask else { return }
        mask = wanted
        HeldOrientation.shared.follow(locked)
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            scene.windows.first?.rootViewController?
                .setNeedsUpdateOfSupportedInterfaceOrientations()
            if locked { scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) }
        }
    }
}

/// How far an icon turns to stand upright for a phone held sideways under a locked screen.
@MainActor
final class HeldOrientation: ObservableObject {
    static let shared = HeldOrientation()

    @Published private(set) var iconTurn: Angle = .zero
    private var observer: NSObjectProtocol?

    func follow(_ following: Bool) {
        if following, observer == nil {
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            observer = NotificationCenter.default.addObserver(
                forName: UIDevice.orientationDidChangeNotification, object: nil, queue: .main
            ) { _ in
                MainActor.assumeIsolated { HeldOrientation.shared.update() }
            }
            update()
        } else if !following, let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
            iconTurn = .zero
        }
    }

    /// Flat on a table or face down says nothing of which way is up: the last turn stays.
    /// Before the first reading, the screen's own orientation says how the phone is held.
    private func update() {
        let turn: Angle
        switch UIDevice.current.orientation {
        case .portrait: turn = .zero
        case .landscapeLeft: turn = .degrees(90)
        case .landscapeRight: turn = .degrees(-90)
        case .portraitUpsideDown: turn = .degrees(180)
        default:
            guard let interface = Self.interfaceTurn() else { return }
            turn = interface
        }
        withAnimation(.snappy) { iconTurn = turn }
    }

    /// The turn that stands an icon upright for the interface's orientation, as it is before
    /// the lock brings the screen back to portrait; nil once the screen is upright, which
    /// says nothing of the phone.
    private static func interfaceTurn() -> Angle? {
        let scene = UIApplication.shared.connectedScenes.lazy
            .compactMap { $0 as? UIWindowScene }.first { $0.activationState == .foregroundActive }
        switch scene?.effectiveGeometry.interfaceOrientation {
        case .landscapeRight: return .degrees(90)
        case .landscapeLeft: return .degrees(-90)
        case .portraitUpsideDown: return .degrees(180)
        default: return nil
        }
    }
}

private struct TurnsWithPhone: ViewModifier {
    @ObservedObject private var held = HeldOrientation.shared

    func body(content: Content) -> some View {
        content.rotationEffect(held.iconTurn)
    }
}

extension View {
    /// Turned upright for the way the phone is held, while the screen is locked upright.
    func turnsWithPhone() -> some View {
        modifier(TurnsWithPhone())
    }
}
#else
enum OrientationLock {
    static func portrait(_ locked: Bool) {}
}

extension View {
    func turnsWithPhone() -> some View { self }
}
#endif
