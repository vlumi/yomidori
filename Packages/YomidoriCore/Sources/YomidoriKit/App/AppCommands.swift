import Combine
import SwiftUI

/// What the menu bar asks of the app, on a Mac: a tab by its key. Public, since the menus
/// are the app target's; the root takes each request and clears it.
@MainActor
public final class AppCommands: ObservableObject {
    public static let shared = AppCommands()

    @Published public var requestedTab: AppTab?
    /// Bumped by File › Open…: a picture of a page from a file, on the Read tab.
    @Published public var openAsked = 0

    private init() {}
}

/// The View menu's way to each section, ⌘1 … ⌘4 on a Mac, where Read is the first.
public struct SectionCommands: Commands {
    public init() {}

    public var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button {
                AppCommands.shared.requestedTab = .read
                AppCommands.shared.openAsked += 1
            } label: {
                Text("Open a Picture…", bundle: .module)
            }
            .keyboardShortcut("o", modifiers: .command)
        }
        CommandGroup(before: .sidebar) {
            section(Text("Read", bundle: .module), .read, "1")
            section(Text("Study", bundle: .module), .study, "2")
            section(Text("Cards", bundle: .module), .cards, "3")
            section(Text("Search", bundle: .module), .search, "4")
            Divider()
        }
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
