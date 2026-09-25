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

    /// `-yomidori-screen progress` pushes that screen on the tab shown, for the same reason.
    static var screen: Screen? {
        guard isRequested, let index = CommandLine.arguments.firstIndex(of: "-yomidori-screen"),
            index + 1 < CommandLine.arguments.count
        else { return nil }
        return Screen(demoName: CommandLine.arguments[index + 1])
    }

    /// The settings suite, emptied at launch; nil outside the demo.
    public static let defaults: UserDefaults? = {
        guard isRequested, let defaults = UserDefaults(suiteName: suite) else { return nil }
        defaults.removePersistentDomain(forName: suite)
        // Live Text does not run on the simulator, so the strip is the way to a word: open.
        defaults.set(true, forKey: SettingsKey.transcriptExpanded)
        return defaults
    }()

    /// The stores' folder, fresh and seeded; created once per launch.
    static let directory: URL = {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "yomidori-demo", isDirectory: true)
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()
}
