import SwiftUI

struct SettingsView: View {
    @AppStorage(SwipeBack.key) private var swipeBack = true
    @AppStorage(SettingsKey.iCloudSync) private var iCloudSync = true
    @AppStorage(SettingsKey.pageControlsSide) private var controlsSide: PageControlsSide = .right
    @AppStorage(SettingsKey.appBadge) private var appBadge = false
    /// The reader turned the count on, but notifications are off for the app.
    @State private var badgeRefused = false
    @ObservedObject private var sync = Sync.shared

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $swipeBack) {
                    Text("Swipe back", bundle: .module)
                }
            } footer: {
                Text(
                    // swiftlint:disable:next line_length
                    "Swiping in from the left edge goes back a screen, as everywhere on iOS. Off, only the back button does, so a swipe meant for a word never leaves the page.",
                    bundle: .module)
            }
            Section {
                Picker(selection: $controlsSide) {
                    Text("Left", bundle: .module).tag(PageControlsSide.left)
                    Text("Right", bundle: .module).tag(PageControlsSide.right)
                } label: {
                    Text("Page controls", bundle: .module)
                }
            } footer: {
                Text(
                    // swiftlint:disable:next line_length
                    "The zoom and the page buttons stand in one column on this side of the picture, the zoom nearest your thumb: the side of the hand that holds the phone.",
                    bundle: .module)
            }
            Section {
                Toggle(isOn: $appBadge) {
                    Text("Reviews due on the app icon", bundle: .module)
                }
                .onChange(of: appBadge) { _, on in
                    Task { @MainActor in
                        if on, !(await AppBadge.requestPermission()) {
                            appBadge = false
                            badgeRefused = true
                        } else {
                            badgeRefused = false
                        }
                        AppBadge.refresh()
                    }
                }
            } footer: {
                if badgeRefused {
                    Text(
                        // swiftlint:disable:next line_length
                        "Notifications are off for Yomidori. Turn on badges for it in the Settings app, under Notifications, then here again.",
                        bundle: .module)
                } else {
                    Text(
                        // swiftlint:disable:next line_length
                        "The number of questions due, kept up to date while the app is closed. Only the number: no banners, no sounds.",
                        bundle: .module)
                }
            }
            Section {
                if let shortcuts = URL(string: "shortcuts://") {
                    Link(destination: shortcuts) {
                        Label {
                            Text("Open Shortcuts", bundle: .module)
                        } icon: {
                            Image(systemName: "square.2.layers.3d")
                        }
                    }
                }
            } header: {
                Text("Read any screen", bundle: .module)
            } footer: {
                Text(
                    // swiftlint:disable:next line_length
                    "In the Shortcuts app, make a shortcut of two actions, Take Screenshot and then Read in Yomidori, and set it to Back Tap (Settings, Accessibility, Touch) or the Action button. A double tap on the back of the phone then opens whatever is on the screen here, ready to tap. Nothing is saved to Photos.",
                    bundle: .module)
            }
            Section {
                Toggle(isOn: $iCloudSync) {
                    Text("Sync with iCloud", bundle: .module)
                }
                .onChange(of: iCloudSync) { _, on in
                    if on { sync.start() } else { sync.stop() }
                }
                if iCloudSync {
                    syncStatus
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text(
                    // swiftlint:disable:next line_length
                    "Your cards, collections with their covers, and lookup history, kept the same on your devices through your own iCloud. Nothing goes anywhere else.",
                    bundle: .module)
            }
            if let url = Cards.store?.url, FileManager.default.fileExists(atPath: url.path) {
                Section {
                    ShareLink(item: url) {
                        Label {
                            Text("Back up cards", bundle: .module)
                        } icon: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                } footer: {
                    Text(
                        "Your cards as one small file, to keep a copy wherever you like.",
                        bundle: .module)
                }
            }
        }
        .tint(Palette.nightGreen)
        .navigationTitle(Text("Settings", bundle: .module))
    }

    @ViewBuilder private var syncStatus: some View {
        switch sync.status {
        case .off: Text("Starting…", bundle: .module)
        case .noAccount: Text("Sign in to iCloud in Settings to sync.", bundle: .module)
        case .syncing: Text("Syncing…", bundle: .module)
        case .upToDate: Text("Up to date", bundle: .module)
        case .failed(let message): Text("Sync failed: \(message)", bundle: .module)
        }
    }
}
