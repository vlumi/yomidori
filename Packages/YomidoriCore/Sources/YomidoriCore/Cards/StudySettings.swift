import Foundation

/// The settings that shape the study and so must be the same on every device: the retention
/// the schedule aims at, and how a lesson is drawn. Kept as one record with the time it was
/// last changed; the later change wins between devices. What a device keeps to itself — its
/// look, its hand, its layout — is not here.
public struct StudySettings: Codable, Equatable, Sendable {
    public var retention: Double
    public var lessonOrder: Lesson.Order
    public var lessonSize: Int
    public var modified: Date

    /// The one record's key in its store and in sync.
    public static let key = "settings"
    public static let lessonSizes = 1...50

    public init(retention: Double, lessonOrder: Lesson.Order, lessonSize: Int, modified: Date) {
        self.retention = retention
        self.lessonOrder = lessonOrder
        self.lessonSize = lessonSize
        self.modified = modified
    }

    /// The later change; this one on a tie, so a record going round does not keep changing.
    public func merged(with other: StudySettings) -> StudySettings {
        other.modified > modified ? other : self
    }

    /// The same values, whenever they were set.
    public func sameValues(as other: StudySettings) -> Bool {
        retention == other.retention && lessonOrder == other.lessonOrder
            && lessonSize == other.lessonSize
    }
}

extension StudySettings: Sanitizable {
    /// Nil for values the app would not offer, or a change dated well into the future.
    public func sanitized() -> StudySettings? {
        guard FSRS.retentions.contains(retention), Self.lessonSizes.contains(lessonSize),
            let modified = SyncPayload.clearDate(modified)
        else { return nil }
        return StudySettings(
            retention: retention, lessonOrder: lessonOrder, lessonSize: lessonSize,
            modified: modified)
    }
}

/// The study settings in a file of their own, one record, written as the stores are and
/// reported the same way, so sync carries it.
public final class FileStudySettings: @unchecked Sendable {
    public let file: RecordFile<StudySettings>

    public init(url: URL) {
        file = RecordFile(url: url, label: "fi.misaki.yomidori.settings") { _ in
            StudySettings.key
        }
    }

    public func settings() -> StudySettings? {
        file.records().first
    }

    /// This device's change, dated now.
    public func update(_ settings: StudySettings) throws {
        try file.write { all in all = [settings] }
    }

    /// Another device's record, laid over this one where it is the later.
    public func applyRemote(_ remote: StudySettings) throws {
        try file.write(.remote) { all in
            all = [all.first.map { $0.merged(with: remote) } ?? remote]
        }
    }
}
