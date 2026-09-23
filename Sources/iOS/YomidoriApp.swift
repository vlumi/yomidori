import SwiftUI
import UIKit
import YomidoriKit

@main
struct YomidoriApp: App {
    @UIApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        WindowGroup {
            AppRoot()
                .defaultAppStorage(DemoMode.defaults ?? .standard)
        }
    }
}

/// Registers for the silent pushes CloudKit sends when another device syncs; the sync
/// engine takes them from there.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }
}
