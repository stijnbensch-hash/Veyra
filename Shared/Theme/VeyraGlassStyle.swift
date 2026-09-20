import SwiftUI

struct VeyraGlassPanel: ViewModifier {
    var radius: CGFloat = VeyraRadius.panel
    var backgroundOpacity: CGFloat = 1.0
    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    Color(red: 0.02, green: 0.045, blue: 0.065).opacity(0.74)
                    LinearGradient(
                        colors: [VeyraColors.cyan.opacity(0.06), .clear, VeyraColors.red.opacity(0.05)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .blendMode(.screen)
                }
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .opacity(backgroundOpacity)
            }
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(backgroundOpacity)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [VeyraColors.ice.opacity(0.28), .white.opacity(0.08), VeyraColors.red.opacity(0.20)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.36), radius: 24, y: 14)
    }
}
extension View {
    func veyraGlass(radius: CGFloat = VeyraRadius.panel, backgroundOpacity: CGFloat = 1.0) -> some View {
        modifier(VeyraGlassPanel(radius: radius, backgroundOpacity: backgroundOpacity))
    }
}
