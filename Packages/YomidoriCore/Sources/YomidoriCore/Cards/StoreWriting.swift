import Foundation

extension Data.WritingOptions {
    /// How the stores are written: whole or not at all, and on a phone unreadable while it
    /// is locked unless the file was already open, which is what lets sync's pushes still
    /// write in the background. The default class would leave the cards and the lookup
    /// history readable from first unlock on.
    public static var store: Data.WritingOptions {
        #if os(iOS)
        [.atomic, .completeFileProtectionUnlessOpen]
        #else
        [.atomic]
        #endif
    }
}
