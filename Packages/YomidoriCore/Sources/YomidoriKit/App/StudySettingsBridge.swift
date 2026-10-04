import Combine
import Foundation
import YomidoriCore

/// The study settings live in the defaults, where the screens read them, and in a record
/// sync carries. This keeps the two the same: a change in the defaults goes to the record,
/// dated now, so it reaches the other devices; a record from another device goes to the
/// defaults, so the screens follow. Not in the demo, which keeps nothing.
@MainActor
final class StudySettingsBridge {
    static let shared = StudySettingsBridge()
    private var subscriptions: Set<AnyCancellable> = []

    func start() {
        guard subscriptions.isEmpty, !DemoMode.isRequested, let store = Cards.studySettings
        else { return }
        if let stored = store.settings() {
            apply(stored)
        } else {
            // The first run with a record: the defaults as they stand, dated at the epoch so
            // a change made anywhere since wins over them.
            try? store.update(current(modified: Date(timeIntervalSince1970: 0)))
        }
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.defaultsChanged() }
            .store(in: &subscriptions)
        Cards.changes(of: [.settings])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                if let stored = Cards.studySettings?.settings() { self?.apply(stored) }
            }
            .store(in: &subscriptions)
    }

    /// The defaults' values as a record.
    private func current(modified: Date) -> StudySettings {
        let defaults = Cards.defaults
        let order = defaults.string(forKey: SettingsKey.lessonOrder).flatMap(Lesson.Order.init)
        let size = defaults.object(forKey: SettingsKey.lessonSize) as? Int
        let retention = defaults.object(forKey: SettingsKey.retention) as? Double
        return StudySettings(
            retention: retention ?? FSRS.desiredRetention, lessonOrder: order ?? .oldest,
            lessonSize: size ?? 5, modified: modified)
    }

    private func defaultsChanged() {
        guard let store = Cards.studySettings else { return }
        let now = current(modified: Date())
        if let stored = store.settings(), stored.sameValues(as: now) { return }
        Cards.write { try store.update(now) }
    }

    /// The record's values into the defaults, only where they differ, so the defaults'
    /// own notice of the change finds nothing to send back.
    private func apply(_ settings: StudySettings) {
        let defaults = Cards.defaults
        if defaults.object(forKey: SettingsKey.retention) as? Double != settings.retention {
            defaults.set(settings.retention, forKey: SettingsKey.retention)
        }
        if defaults.string(forKey: SettingsKey.lessonOrder) != settings.lessonOrder.rawValue {
            defaults.set(settings.lessonOrder.rawValue, forKey: SettingsKey.lessonOrder)
        }
        if defaults.object(forKey: SettingsKey.lessonSize) as? Int != settings.lessonSize {
            defaults.set(settings.lessonSize, forKey: SettingsKey.lessonSize)
        }
    }
}
