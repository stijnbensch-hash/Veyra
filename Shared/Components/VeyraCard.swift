import SwiftUI

/// Gedeelde visuele basis voor een "kaart"-achtige knop of container:
/// de gradient, rand en gloed, zonder aannames over hoe activering
/// wordt gedetecteerd (tvOS-focus, iOS-aanraking, ...).
///
/// Platformwrappers zoals `VeyraTVCard` passen dit toe op basis van
/// hun eigen activeringssignaal (bijvoorbeeld `@Environment(\.isFocused)`).
struct VeyraCard {
    var radius: CGFloat = VeyraRadius.card
    var primary = false

    @ViewBuilder
    func apply<Content: View>(to content: Content, isActive: Bool, isPressed: Bool) -> some View {
        content
            .background(
                primary
                    ? LinearGradient(
                        colors: [VeyraColors.cyan.opacity(isActive ? 0.60 : 0.30), VeyraColors.cyan.opacity(0.14)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    : LinearGradient(
                        colors: [Color.white.opacity(isActive ? 0.18 : 0.06), Color.white.opacity(0.025)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                in: RoundedRectangle(cornerRadius: radius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(
                        isActive
                            ? LinearGradient(colors: [VeyraColors.ice, VeyraColors.cyan, VeyraColors.red.opacity(0.70)], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [.white.opacity(primary ? 0.24 : 0.10)], startPoint: .leading, endPoint: .trailing),
                        lineWidth: isActive ? 2 : 1
                    )
            )
            .shadow(color: isActive ? VeyraColors.cyan.opacity(0.30) : .clear, radius: 18, x: -5, y: 3)
            .shadow(color: isActive ? VeyraColors.red.opacity(0.18) : .clear, radius: 18, x: 8, y: 3)
            .scaleEffect(isPressed ? 0.98 : isActive ? 1.035 : 1)
    }
}
