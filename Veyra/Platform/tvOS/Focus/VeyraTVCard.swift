import SwiftUI

/// tvOS-focuswrapper rond `VeyraCard`: voegt de focus-gloed voor
/// Siri Remote-navigatie toe, boven op de gedeelde kaartstijl.
struct VeyraTVCard: ButtonStyle {
    var radius: CGFloat = VeyraRadius.card
    var primary = false

    func makeBody(configuration: Configuration) -> some View {
        VeyraTVCardLabel(
            configuration: configuration,
            card: VeyraCard(radius: radius, primary: primary)
        )
    }
}

private struct VeyraTVCardLabel: View {
    let configuration: ButtonStyleConfiguration
    let card: VeyraCard

    @Environment(\.isFocused) private var focused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        card.apply(
            to: configuration.label,
            isActive: focused,
            isPressed: configuration.isPressed
        )
        .animation(reduceMotion ? nil : VeyraAnimation.focus, value: focused)
    }
}

/// Backwards-compatible naam: bestaande call sites door de hele app
/// gebruiken deze stijl nog steeds als `VeyraFocusButtonStyle`.
typealias VeyraFocusButtonStyle = VeyraTVCard
