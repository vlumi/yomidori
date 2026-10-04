import Foundation

enum Screen: Hashable, Codable {
    case review
    case about
    case settings
    case lesson
    case collections
    case progress
    /// The drill after a lesson, over the cards it started.
    case practice([UUID])

    /// The screen `-yomidori-screen` names; only the ones a tab's root can push.
    init?(demoName: String) {
        switch demoName {
        case "review": self = .review
        case "lesson": self = .lesson
        case "progress": self = .progress
        case "settings": self = .settings
        case "about": self = .about
        case "collections": self = .collections
        default: return nil
        }
    }
}
