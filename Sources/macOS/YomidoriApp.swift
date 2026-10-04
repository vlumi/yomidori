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
                .frame(minWidth: 1000, minHeight: 600)
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
            // The sections, ⌘1 … ⌘4, in the View menu.
            SectionCommands()
        }
        // Settings is ⌘, as on every Mac.
        Settings {
            NavigationStack {
                SettingsView()
                    .defaultAppStorage(DemoMode.defaults ?? .standard)
            }
            .chosenAppearance()
            .frame(width: 560, height: 620)
        }
        Window(Text("About Yomidori"), id: "about") {
            NavigationStack {
                AboutView()
                    .defaultAppStorage(DemoMode.defaults ?? .standard)
            }
            .chosenAppearance()
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
        #if DEBUG
        WindowShots.startIfAsked()
        #endif
    }

    /// One window, and the app goes with it, as a small utility does.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

#if DEBUG
/// A development aid: launched with `-yomidori-shots <seconds>`, the app saves a picture of
/// its window to `Shots/` in its container every so many seconds, for a session that cannot
/// see the screen (an agent's terminal, a CI log) to look at. Nothing without the argument,
/// and not in a release build at all.
enum WindowShots {
    static func startIfAsked() {
        guard let index = CommandLine.arguments.firstIndex(of: "-yomidori-shots"),
            index + 1 < CommandLine.arguments.count,
            let seconds = Double(CommandLine.arguments[index + 1]), seconds > 0
        else { return }
        let folder = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Shots", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var count = 0
        Timer.scheduledTimer(withTimeInterval: seconds, repeats: true) { _ in
            guard let window = NSApp.keyWindow ?? NSApp.windows.first(where: \.isVisible),
                let view = window.contentView, let layer = view.layer
            else { return }
            let scale = window.backingScaleFactor
            let width = Int(view.bounds.width * scale)
            let height = Int(view.bounds.height * scale)
            guard width > 0, height > 0,
                let context = CGContext(
                    data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
            else { return }
            context.scaleBy(x: scale, y: scale)
            // The layer tree is drawn y-down; the context is y-up.
            context.translateBy(x: 0, y: view.bounds.height)
            context.scaleBy(x: 1, y: -1)
            layer.render(in: context)
            guard let image = context.makeImage() else { return }
            let bitmap = NSBitmapImageRep(cgImage: image)
            guard let png = bitmap.representation(using: .png, properties: [:]) else { return }
            count += 1
            try? png.write(
                to: folder.appendingPathComponent(String(format: "shot-%03d.png", count)))
        }
    }
}
#endif
