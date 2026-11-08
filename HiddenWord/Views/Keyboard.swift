import SwiftUI
import UIKit

/// Small helpers so the keyboard never traps the user.
enum Keyboard {
    /// Closes the keyboard, whichever field has it.
    static func dismiss() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

extension View {
    /// Adds a "Done" button above the keyboard. Put it once on a screen.
    func keyboardDoneButton() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { Keyboard.dismiss() }
                    .fontWeight(.semibold)
            }
        }
    }

    /// Calls `onChange(true)` when the keyboard appears and `onChange(false)` when it goes away.
    func onKeyboardVisibilityChange(_ onChange: @escaping (Bool) -> Void) -> some View {
        self
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in onChange(true) }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in onChange(false) }
    }
}
