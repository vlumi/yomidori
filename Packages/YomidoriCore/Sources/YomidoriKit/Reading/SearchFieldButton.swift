import SwiftUI

#if os(iOS)
import UIKit

/// A button at the end of the search box itself. SwiftUI's search field takes no accessory
/// (the keyboard toolbar does not reach it, the tab's search field no toolbar items), so once
/// the field has the keyboard this finds it, a `UISearchTextField`, and puts the button in
/// its right view. Nothing happens if the field is not found.
@MainActor
final class SearchFieldButton {
    private let symbol: String
    private let label: String
    private let action: () -> Void
    private var button: UIButton?

    init(symbol: String, label: String, action: @escaping () -> Void) {
        self.symbol = symbol
        self.label = label
        self.action = action
    }

    /// Tried for a moment until the field has the keyboard: SwiftUI hands it over late, most
    /// of all to a tab that takes the keyboard as it is shown.
    func install() async {
        for _ in 0..<20 {
            if attach() || Task.isCancelled { return }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    /// True once the field with the keyboard has the button; put back if the field dropped it.
    private func attach() -> Bool {
        guard let field = FirstResponder.current as? UISearchTextField else { return false }
        let button = button ?? makeButton()
        if field.rightView !== button {
            field.rightView = button
            field.rightViewMode = .always
        }
        return true
    }

    private func makeButton() -> UIButton {
        let button = UIButton(
            type: .system,
            primaryAction: UIAction(image: UIImage(systemName: symbol)) { [weak self] _ in
                self?.action()
            })
        button.accessibilityLabel = label
        button.tintColor = UIColor(Palette.nightGreen)
        button.frame = CGRect(x: 0, y: 0, width: 36, height: 36)
        self.button = button
        return button
    }
}

/// The view holding the keyboard, found by asking it to answer an action sent to no one.
private enum FirstResponder {
    nonisolated(unsafe) static weak var found: UIResponder?

    static var current: UIResponder? {
        found = nil
        UIApplication.shared.sendAction(
            #selector(UIResponder.yomidoriReport), to: nil, from: nil, for: nil)
        return found
    }
}

extension UIResponder {
    @objc fileprivate func yomidoriReport() {
        FirstResponder.found = self
    }
}
#else
@MainActor
final class SearchFieldButton {
    init(symbol: String, label: String, action: @escaping () -> Void) {}
    func install() async {}
}
#endif
