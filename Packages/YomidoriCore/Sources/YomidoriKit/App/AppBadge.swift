import Foundation
import UserNotifications
import YomidoriCore

/// The questions due as a number on the app icon, when the reader turns it on in Settings.
/// Now, set at once; later, while the app is closed, by silent notifications that carry only
/// the count, one for each hour a question comes due (`BadgeSchedule`). Redone whenever the
/// cards change, a sync included, and as the app goes to the background.
@MainActor
enum AppBadge {
    static var isOn: Bool {
        !DemoMode.isRequested && Cards.defaults.bool(forKey: SettingsKey.appBadge)
    }

    /// Asks for badges alone: no alert, no sound. False when the reader said no.
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.badge]))
            ?? false
    }

    private static let prefix = "fi.misaki.yomidori.badge."
    /// Steps scheduled at most: under the 64 notifications iOS keeps pending for an app.
    private static let steps = 60

    static func refresh() {
        let center = UNUserNotificationCenter.current()
        // The last set goes before the new one is added; the center keeps the calls in order.
        center.removePendingNotificationRequests(
            withIdentifiers: (0..<steps).map { "\(prefix)\($0)" })
        guard isOn else {
            center.setBadgeCount(0)
            return
        }
        let now = Date()
        let cards = Cards.store?.cards() ?? []
        let base = Cards.dueItems(at: now).count
        center.setBadgeCount(base)
        let dates = cards.flatMap { card in
            card.upcomingDue(
                after: now, asksPitch: card.isInReview && !Cards.accents(of: card).isEmpty)
        }
        for (index, step) in BadgeSchedule.steps(
            dueDates: dates, after: now, base: base, limit: steps
        ).enumerated() {
            let content = UNMutableNotificationContent()
            content.badge = NSNumber(value: step.count)
            content.interruptionLevel = .passive
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, step.date.timeIntervalSince(now)), repeats: false)
            center.add(
                UNNotificationRequest(
                    identifier: "\(prefix)\(index)", content: content, trigger: trigger))
        }
    }
}
