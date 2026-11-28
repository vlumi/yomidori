import Foundation

/// Where a card was put and when: into review, back to waiting, on the shelf. With the
/// log, what the ranks by day are replayed from (`RankHistory`).
public struct CardMove: Hashable, Codable, Sendable {
    public enum Standing: String, Codable, Sendable {
        case started
        case waiting
        case shelved
    }

    public let date: Date
    public let standing: Standing

    public init(date: Date, standing: Standing) {
        self.date = date
        self.standing = standing
    }
}
