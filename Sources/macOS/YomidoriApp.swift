import AppKit
import SwiftUI
import YomidoriKit

@main
struct YomidoriApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        WindowGroup {
            AppRoot()
                .defaultAppStorage(DemoMode.defaults ?? .standard)
        }
    }
}

/// Registers for the silent pushes CloudKit sends when another device syncs; the sync
/// engine takes them from there.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.registerForRemoteNotifications()
    }

    /// One window, and the app goes with it, as a small utility does.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
