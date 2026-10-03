import SwiftUI
import YomidoriCore

public struct SettingsView: View {
    public init() {}

    @AppStorage(SwipeBack.key) private var swipeBack = true
    @AppStorage(SettingsKey.iCloudSync) private var iCloudSync = true
    @AppStorage(SettingsKey.pageControlsSide) private var controlsSide: PageControlsSide = .right
    @AppStorage(SettingsKey.appBadge) private var appBadge = false
    @AppStorage(SettingsKey.retention) private var retention = FSRS.desiredRetention
    @AppStorage(SettingsKey.language) private var language: AppLanguage = .system
    @AppStorage(SettingsKey.appearance) private var appearance: Appearance = .system
    /// The reader turned the count on, but notifications are off for the app.
    @State private var badgeRefused = false
    @State private var choosingBackup = false
    @State private var restored: BackupRestore?
    @State private var restoreFailed = false
    @ObservedObject private var sync = Sync.shared

    public var body: some View {
        Form {
            #if os(iOS)
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
            #endif
            Section {
                Picker(selection: $appearance) {
                    ForEach(Appearance.allCases) { appearance in
                        appearance.label.tag(appearance)
                    }
                } label: {
                    Text("Appearance", bundle: .module)
                }
            }
            Section {
                Picker(selection: $language) {
                    ForEach(AppLanguage.allCases) { language in
                        language.label.tag(language)
                    }
                } label: {
                    Text("Language", bundle: .module)
                }
                .onAppear { if AppLanguage.atLaunch == nil { AppLanguage.atLaunch = language } }
                .onChange(of: language) { _, chosen in AppLanguage.apply(chosen) }
            } footer: {
                if let atLaunch = AppLanguage.atLaunch, language != atLaunch {
                    Label {
                        Text("Open the app again to see it in this language.", bundle: .module)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                } else {
                    Text("Shows when the app is next opened.", bundle: .module)
                }
            }
            Section {
                Picker(selection: $retention) {
                    Text("90 %", bundle: .module).tag(0.9)
                    Text("95 %", bundle: .module).tag(0.95)
                } label: {
                    Text("Aim to remember", bundle: .module)
                }
            } footer: {
                Text(
                    // swiftlint:disable:next line_length
                    "The share of reviews you should get right when a word comes up. At 95 % each word comes back about twice as often as at 90 %. Counts from the next answer, on this device.",
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
            #if os(iOS)
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
            #endif
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
            if Cards.store != nil {
                Section {
                    ShareLink(
                        item: BackupFile(),
                        preview: SharePreview(Text("Yomidori backup", bundle: .module))
                    ) {
                        Label {
                            Text("Back up cards", bundle: .module)
                        } icon: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    Button {
                        choosingBackup = true
                    } label: {
                        Label {
                            Text("Restore a backup", bundle: .module)
                        } icon: {
                            Image(systemName: "square.and.arrow.down")
                        }
                    }
                } footer: {
                    Text(
                        // swiftlint:disable:next line_length
                        "Your cards, collections and lookup history as one file, to keep a copy wherever you like; the covers are not in it. Restoring adds what a backup has to what is here, and takes nothing away.",
                        bundle: .module)
                }
            }
        }
        .tint(Palette.nightGreen)
        .settingsFormStyle()
        .fileImporter(isPresented: $choosingBackup, allowedContentTypes: [.json]) { result in
            if case .success(let url) = result, let done = try? Cards.restoreBackup(from: url) {
                restored = done
            } else if case .success = result {
                restoreFailed = true
            }
        }
        .alert(
            Text("Backup restored", bundle: .module), isPresented: restoredShown,
            presenting: restored
        ) { _ in
        } message: { done in
            Text(
                // swiftlint:disable:next line_length
                "\(done.addedCards) cards added, \(done.joinedCards) joined with cards already here, \(done.addedCollections) collections added.",
                bundle: .module)
        }
        .alert(
            Text("That file is not a Yomidori backup.", bundle: .module),
            isPresented: $restoreFailed
        ) {
        }
        .navigationTitle(Text("Settings", bundle: .module))
    }

    private var restoredShown: Binding<Bool> {
        Binding(get: { restored != nil }, set: { if !$0 { restored = nil } })
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
