import SwiftUI

// iPhone-only presentation hints have no direct counterpart in a Mac window.
// These adapters let the shared screens retain their existing navigation and
// form controls while AppKit supplies the native window chrome and text input.
enum MacTitleDisplayMode {
    case inline
}

enum MacTextAutocapitalization {
    case never
    case words
}

enum MacKeyboardType {
    case URL
    case numberPad
}

extension View {
    func navigationBarTitleDisplayMode(_ mode: MacTitleDisplayMode) -> some View { self }
    func keyboardType(_ type: MacKeyboardType) -> some View { self }
}

extension TextField {
    func textInputAutocapitalization(_ mode: MacTextAutocapitalization) -> Self { self }
    func keyboardType(_ type: MacKeyboardType) -> Self { self }
}

extension SecureField {
    func textInputAutocapitalization(_ mode: MacTextAutocapitalization) -> Self { self }
}

extension ToolbarItemPlacement {
    static var topBarTrailing: ToolbarItemPlacement { .automatic }
    static var navigationBarLeading: ToolbarItemPlacement { .automatic }
}

struct FloatingIconButton: View {
    let symbol: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(VeyraColors.cyan.opacity(0.55), lineWidth: 1))
        }
        .accessibilityLabel(accessibilityLabel)
    }
}
