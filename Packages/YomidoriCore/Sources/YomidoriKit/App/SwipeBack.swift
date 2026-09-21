import SwiftUI

#if os(iOS)
import UIKit
#endif

/// The system's edge swipe that pops a screen, on by default as iOS has it; a reader who
/// keeps swiping back by accident turns it off in Settings, for every screen.
enum SwipeBack {
    static let key = "swipeBack"
}

extension View {
    /// Applies the setting to the navigation controller this screen sits in.
    func swipeBackSetting() -> some View {
        modifier(SwipeBackSetting())
    }
}

private struct SwipeBackSetting: ViewModifier {
    @AppStorage(SwipeBack.key) private var enabled = true

    func body(content: Content) -> some View {
        #if os(iOS)
        content.background(SwipeBackSetter(enabled: enabled))
        #else
        content
        #endif
    }
}

#if os(iOS)
/// The pop gesture belongs to the navigation controller, reached through the parent chain
/// once this controller has been added to the screen's hosting controller.
private struct SwipeBackSetter: UIViewControllerRepresentable {
    let enabled: Bool

    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.enabled = enabled
        controller.apply()
    }

    final class Controller: UIViewController {
        var enabled = true

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            apply()
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            apply()
        }

        func apply() {
            navigationController?.interactivePopGestureRecognizer?.isEnabled = enabled
        }
    }
}
#endif
