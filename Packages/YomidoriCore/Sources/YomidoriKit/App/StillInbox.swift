import Foundation
import SwiftUI

/// An image handed to the app from outside, a shortcut's screenshot for one: checked and
/// decoded as any image coming in is, then opened on the Read tab as the still.
@MainActor
public final class StillInbox: ObservableObject {
    public static let shared = StillInbox()

    @Published private(set) var arrival: Still?

    /// False for what is no image, or one too large to be a photo.
    @discardableResult
    public func receive(_ data: Data) -> Bool {
        guard let still = Still(data: data) else { return false }
        arrival = still
        return true
    }

    func clear() {
        arrival = nil
    }
}
