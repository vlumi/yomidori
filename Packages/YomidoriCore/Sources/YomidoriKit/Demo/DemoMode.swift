import Foundation
import YomidoriCore

/// Launched with `-yomidori-demo`, every store lives in a folder wiped and reseeded at each
/// start with fixed public-domain data, and the settings in their own suite, so the
/// simulator shows a full app and the real data is never touched.
public enum DemoMode {
    static let argument = "-yomidori-demo"
    static let suite = "fi.misaki.yomidori.demo"

    public static var isRequested: Bool {
        CommandLine.arguments.contains(argument)
    }

    /// `-yomidori-tab search` opens the demo on that tab, for looking at a screen or taking
    /// its screenshot without a hand on the simulator.
    static var tab: AppTab? {
        guard isRequested, let index = CommandLine.arguments.firstIndex(of: "-yomidori-tab"),
            index + 1 < CommandLine.arguments.count
        else { return nil }
        return AppTab(rawValue: CommandLine.arguments[index + 1])
    }

    /// `-yomidori-card 名前` picks that card in Cards, so a split shows it beside the list.
    static var card: String? { value(after: "-yomidori-card") }

    /// `-yomidori-entry 見る` picks that result in the dictionary, for its entry column.
    static var entry: String? { value(after: "-yomidori-entry") }

    private static func value(after flag: String) -> String? {
        guard isRequested, let index = CommandLine.arguments.firstIndex(of: flag),
            index + 1 < CommandLine.arguments.count
        else { return nil }
        return CommandLine.arguments[index + 1]
    }

    /// `-yomidori-begin` begins the lesson at once, past its setup, for a look at its pages.
    static var beginsLesson: Bool {
        isRequested && CommandLine.arguments.contains("-yomidori-begin")
    }

    /// `-yomidori-screen progress` pushes that screen on the tab shown, for the same reason.
    static var screen: Screen? {
        guard isRequested, let index = CommandLine.arguments.firstIndex(of: "-yomidori-screen"),
            index + 1 < CommandLine.arguments.count
        else { return nil }
        return Screen(demoName: CommandLine.arguments[index + 1])
    }

    /// `-yomidori-search 見当` fills the search field, for a look at its results.
    static var search: String? {
        guard isRequested, let index = CommandLine.arguments.firstIndex(of: "-yomidori-search"),
            index + 1 < CommandLine.arguments.count
        else { return nil }
        return CommandLine.arguments[index + 1]
    }

    /// `-yomidori-spread` opens the Read tab on two pages, for a look at a spread.
    static var spread: Bool {
        isRequested && CommandLine.arguments.contains("-yomidori-spread")
    }

    /// `-yomidori-pick 見当` opens the Read tab with that text of the page selected and the
    /// drawer half up, for a look at a word's readout; a text that is not on the demo's page
    /// becomes the page, all of it selected, so any phrase can be tried.
    static var pick: String? {
        guard isRequested, let index = CommandLine.arguments.firstIndex(of: "-yomidori-pick"),
            index + 1 < CommandLine.arguments.count
        else { return nil }
        return CommandLine.arguments[index + 1]
    }

    /// `-yomidori-select` opens the card list selecting, a few cards picked, for a look at
    /// the batch bar.
    static var selecting: Bool {
        isRequested && CommandLine.arguments.contains("-yomidori-select")
    }

    /// The settings suite, emptied at launch; nil outside the demo.
    public static let defaults: UserDefaults? = {
        guard isRequested, let defaults = UserDefaults(suiteName: suite) else { return nil }
        defaults.removePersistentDomain(forName: suite)
        // Live Text does not run on the simulator, so the strip is the way to a word: open.
        defaults.set(true, forKey: SettingsKey.transcriptExpanded)
        if let drawer { defaults.set(drawer, forKey: SettingsKey.readoutFraction) }
        return defaults
    }()

    /// `-yomidori-mode vision`: the recognizer the page opens in; Live Text otherwise.
    static var mode: CaptureView.Mode? {
        guard isRequested, let index = CommandLine.arguments.firstIndex(of: "-yomidori-mode"),
            index + 1 < CommandLine.arguments.count
        else { return nil }
        switch CommandLine.arguments[index + 1] {
        case "vision": return .vision
        case "livetext", "live-text": return .liveText
        default: return nil
        }
    }

    /// `-yomidori-recognize`: the demo's page read by the recognizers as any page is, not
    /// taken as read from its text — on a device, or a simulator whose Vision runs, the
    /// words then light up on the picture as they do in use.
    static var recognizes: Bool {
        isRequested && CommandLine.arguments.contains("-yomidori-recognize")
    }

    /// `-yomidori-picture <path>`: a picture file of this machine's as the page, read by the
    /// recognizers as a photo is, for a look at what they make of a real page.
    static var picture: URL? {
        guard isRequested, let index = CommandLine.arguments.firstIndex(of: "-yomidori-picture"),
            index + 1 < CommandLine.arguments.count
        else { return nil }
        return URL(fileURLWithPath: CommandLine.arguments[index + 1])
    }

    /// `-yomidori-nopage`: the Read tab at the camera, no page seeded, for a look at the ways
    /// in; with `-yomidori-spread`, the first page taken and the camera up for the next.
    static var noPage: Bool {
        isRequested && CommandLine.arguments.contains("-yomidori-nopage")
    }

    /// `-yomidori-drawer 0.8`: the drawer under the page at that share of the screen, the
    /// nearest of its stops, for a screenshot that wants the words to have room.
    static var drawer: Double? {
        guard isRequested, let index = CommandLine.arguments.firstIndex(of: "-yomidori-drawer"),
            index + 1 < CommandLine.arguments.count,
            let fraction = Double(CommandLine.arguments[index + 1])
        else { return nil }
        return DrawerDetents.nearest(fraction)
    }

    /// The stores' folder, fresh and seeded; created once per launch.
    static let directory: URL = {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "yomidori-demo", isDirectory: true)
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()
}
