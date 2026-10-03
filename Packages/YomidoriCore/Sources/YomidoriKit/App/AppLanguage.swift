import Foundation
import SwiftUI

/// The app's language: the device's, or one of its own regardless. Chosen in Settings and
/// written to `AppleLanguages`, which the system reads as the app starts, so a change
/// shows when the app is next opened.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english
    case japanese

    var id: String { rawValue }

    /// The language forced, nil to follow the device.
    var code: String? {
        switch self {
        case .system: return nil
        case .english: return "en"
        case .japanese: return "ja"
        }
    }

    /// Each language in its own name; the device's, in the app's.
    var label: Text {
        switch self {
        case .system: return Text("Same as the device", bundle: .module)
        case .english: return Text(verbatim: "English")
        case .japanese: return Text(verbatim: "日本語")
        }
    }

    /// The choice the app started with, for telling the reader a change waits on a restart:
    /// noted by Settings on its first showing, from the same storage its picker reads, and
    /// the choice cannot have changed before that.
    static var atLaunch: AppLanguage?

    /// Hands the choice to the system, for the next start.
    static func apply(_ language: AppLanguage) {
        if let code = language.code {
            UserDefaults.standard.set([code], forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
    }
}
