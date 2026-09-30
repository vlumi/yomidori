import AppKit
import SwiftUI
import YomidoriKit

@main
struct YomidoriApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup {
            AppRoot()
                .defaultAppStorage(DemoMode.defaults ?? .standard)
                .frame(minWidth: 800, minHeight: 500)
        }
        .commands {
            // About is the app menu's, as on every Mac.
            CommandGroup(replacing: .appInfo) {
                Button {
                    openWindow(id: "about")
                } label: {
                    Text("About Yomidori")
                }
            }
        }
        // Settings is ⌘, as on every Mac.
        Settings {
            NavigationStack {
                SettingsView()
                    .defaultAppStorage(DemoMode.defaults ?? .standard)
            }
            .frame(width: 560, height: 620)
        }
        Window(Text("About Yomidori"), id: "about") {
            NavigationStack {
                AboutView()
                    .defaultAppStorage(DemoMode.defaults ?? .standard)
            }
            .frame(width: 520, height: 640)
        }
        .windowResizability(.contentSize)
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
