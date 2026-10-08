import Combine
import SwiftUI

/// What the menu bar, or a key held on an iPad, asks of the app: a tab by its key. Public,
/// since the menus are the app target's; the root takes each request and clears it.
@MainActor
public final class AppCommands: ObservableObject {
    public static let shared = AppCommands()

    @Published public var requestedTab: AppTab?
    /// Bumped by File › Open…: a picture of a page from a file, on the Read tab.
    @Published public var openAsked = 0
    /// Bumped by ⌘, on an iPad, whose Settings is a screen on Home and not a window.
    @Published public var settingsAsked = 0
    /// The Study menu's ask: Review, Lesson or Progress, opened on the Study tab.
    @Published var screenAsked: Screen?
    /// Bumped by ⌘[: the tab showing pops the screen on top of its stack.
    @Published public var backAsked = 0

    private init() {}
}

/// The View menu's way to each section, ⌘1 … ⌘4 with Read the first on every platform, so
/// a key learnt on the Mac holds on an iPad with a keyboard; the iPad's Home is ⌘0, and its
/// ⌘, opens Settings on Home, the Mac having its own window for it. File › Open a Picture…
/// is the Mac's, whose Read takes a file.
public struct SectionCommands: Commands {
    public init() {}

    public var body: some Commands {
        #if os(macOS)
        CommandGroup(replacing: .newItem) {
            Button {
                AppCommands.shared.requestedTab = .read
                AppCommands.shared.openAsked += 1
            } label: {
                Text("Open a Picture…", bundle: .module)
            }
            .keyboardShortcut("o", modifiers: .command)
        }
        #endif
        #if os(iOS)
        CommandGroup(replacing: .appSettings) {
            Button {
                AppCommands.shared.settingsAsked += 1
            } label: {
                Text("Settings…", bundle: .module)
            }
            .keyboardShortcut(",", modifiers: .command)
        }
        #endif
        CommandGroup(before: .sidebar) {
            #if os(iOS)
            section(Text("Home", bundle: .module), .home, "0")
            #endif
            section(Text("Read", bundle: .module), .read, "1")
            section(Text("Study", bundle: .module), .study, "2")
            section(Text("Cards", bundle: .module), .cards, "3")
            section(Text("Dictionary", bundle: .module), .search, "4")
            Divider()
            // ⌘[ as in Safari and the Finder: the screen on top of the tab's stack goes.
            Button {
                AppCommands.shared.backAsked += 1
            } label: {
                Text("Back", bundle: .module)
            }
            .keyboardShortcut("[", modifiers: .command)
            Divider()
        }
        // The study's three doors, from anywhere: ⇧ with the letter, since ⌘R, ⌘L and ⌘P
        // are the system's.
        CommandMenu(Text("Study", bundle: .module)) {
            study(Text("Review", bundle: .module), .review, "r")
            study(Text("Lesson", bundle: .module), .lesson, "l")
            study(Text("Progress", bundle: .module), .progress, "p")
        }
    }

    private func study(_ title: Text, _ screen: Screen, _ key: KeyEquivalent) -> some View {
        Button {
            AppCommands.shared.screenAsked = screen
        } label: {
            title
        }
        .keyboardShortcut(key, modifiers: [.command, .shift])
    }

    private func section(_ title: Text, _ tab: AppTab, _ key: KeyEquivalent) -> some View {
        Button {
            AppCommands.shared.requestedTab = tab
        } label: {
            title
        }
        .keyboardShortcut(key, modifiers: .command)
    }
}
