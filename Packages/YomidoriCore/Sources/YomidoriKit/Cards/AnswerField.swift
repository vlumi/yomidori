import SwiftUI

#if os(iOS)
import UIKit

/// The field an answer is typed in, a UIKit one for what SwiftUI's lacks: a keyboard of its
/// own for each question, remembered apart (kana for the reading, letters for the meaning)
/// through the text input context; it takes the keyboard as it appears, and the return key
/// is one way to check. Made anew for each question (`.id`), as the context is fixed at birth.
struct AnswerField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    /// Which keyboard iOS remembers for this field; one per question.
    let context: String
    let asciiOnly: Bool
    /// The question shown; the field takes the keyboard as it appears, whatever the question.
    var question: AnyHashable = 0
    let submit: () -> Void

    func makeUIView(context: Context) -> UITextField {
        let field = ContextField(context: self.context)
        field.delegate = context.coordinator
        field.borderStyle = .roundedRect
        field.font = .preferredFont(forTextStyle: .title2)
        field.adjustsFontForContentSizeCategory = true
        field.autocapitalizationType = .none
        field.returnKeyType = .done
        field.keyboardType = asciiOnly ? .asciiCapable : .default
        field.placeholder = placeholder
        field.addTarget(
            context.coordinator, action: #selector(Coordinator.edited), for: .editingChanged)
        field.setContentHuggingPriority(.defaultHigh, for: .vertical)
        DispatchQueue.main.async { field.becomeFirstResponder() }
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        if field.text != text { field.text = text }
        context.coordinator.submit = submit
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, submit: submit)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        private let text: Binding<String>
        var submit: () -> Void

        init(text: Binding<String>, submit: @escaping () -> Void) {
            self.text = text
            self.submit = submit
        }

        @objc func edited(_ field: UITextField) {
            text.wrappedValue = field.text ?? ""
        }

        func textFieldShouldReturn(_ field: UITextField) -> Bool {
            submit()
            return true
        }
    }

    /// The context identifier lives on the responder, so a subclass carries it.
    private final class ContextField: UITextField {
        let context: String

        init(context: String) {
            self.context = context
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { nil }

        override var textInputContextIdentifier: String? { context }
    }
}
#else
/// On a Mac the keyboard is the reader's own to switch; the field takes the focus as each
/// question comes, so typing starts at once.
struct AnswerField: View {
    @Binding var text: String
    let placeholder: String
    let context: String
    let asciiOnly: Bool
    /// Changed as each question comes: the field takes the keys again.
    var question: AnyHashable = 0
    let submit: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .onSubmit(submit)
            .textFieldStyle(.roundedBorder)
            .font(.title2)
            .autocorrectionDisabled()
            .focused($focused)
            // Asked once the field is in the window, not as it appears, or AppKit lets it go.
            .onAppear { DispatchQueue.main.async { focused = true } }
            .onChange(of: question) { _, _ in DispatchQueue.main.async { focused = true } }
    }
}
#endif
