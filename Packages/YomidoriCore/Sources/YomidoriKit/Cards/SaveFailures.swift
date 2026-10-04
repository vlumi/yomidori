import SwiftUI

/// A write to the stores that failed — the disk full, the file gone — said once, over
/// whatever screen is up, instead of swallowed: a word kept that was not, an answer that
/// did not land. The root shows it and clears it.
@MainActor
final class SaveFailures: ObservableObject {
    static let shared = SaveFailures()
    @Published var latest: String?

    private init() {}
}

extension Cards {
    /// Every write to the stores from a screen goes through here, so none fails in silence:
    /// what the write returns, nil when it did not take.
    @discardableResult
    @MainActor static func write<Result>(_ action: () throws -> Result) -> Result? {
        do {
            return try action()
        } catch {
            SaveFailures.shared.latest = error.localizedDescription
            return nil
        }
    }
}

extension View {
    /// The notice of a failed write, on the app's root.
    func saveFailureAlert() -> some View {
        modifier(SaveFailureAlert())
    }
}

private struct SaveFailureAlert: ViewModifier {
    @ObservedObject private var failures = SaveFailures.shared

    func body(content: Content) -> some View {
        content.alert(
            Text("Could not save", bundle: .module),
            isPresented: Binding(
                get: { failures.latest != nil }, set: { if !$0 { failures.latest = nil } }),
            presenting: failures.latest
        ) { _ in
        } message: { reason in
            Text(verbatim: reason)
        }
    }
}
