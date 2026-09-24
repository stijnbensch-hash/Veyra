// VeyraBentoPress.swift — iOS 17+ / macOS 14+
// Aanraakstijl voor de bento-tegels: glas met het Veyra-kader (cyaan -> rood) en een lichte indruk-animatie.

#if !os(tvOS)
import SwiftUI

struct VeyraPressStyle: ButtonStyle {
    var cornerRadius: CGFloat = 22

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        configuration.label
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(.ultraThinMaterial, in: shape)
            .clipShape(shape)
            .overlay(shape.strokeBorder(configuration.isPressed ? VeyraFrame.active : VeyraFrame.resting,
                                        lineWidth: configuration.isPressed ? 2 : 1.5))
            .shadow(color: .black.opacity(0.28), radius: 12, y: 6)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
#endif
