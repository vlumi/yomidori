import Foundation
import ImageIO
import SwiftUI

/// An image handed to the app from outside, a shortcut's screenshot for one: checked and
/// decoded as any image coming in is, then opened on the Read tab as the still.
@MainActor
public final class StillInbox: ObservableObject {
    public static let shared = StillInbox()

    @Published private(set) var arrival: Still?

    /// False for what is no image at all; the decoding, which a big screenshot makes a
    /// second's work, is off the main thread, and the still arrives when it is done.
    @discardableResult
    public func receive(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
            CGImageSourceGetCount(source) > 0
        else { return false }
        Still.decode(data) { [weak self] still in self?.arrival = still }
        return true
    }

    func clear() {
        arrival = nil
    }
}
