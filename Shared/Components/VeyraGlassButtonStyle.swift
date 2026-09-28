// VeyraGlassButtonStyle.swift — gedeeld (tvOS/iOS/iPadOS/macOS)
// Cross-platform variant van `VeyraTVCard`/`VeyraFocusButtonStyle` (die zit in de tvOS-app-target
// en gebruikt tvOS-remote-focus) -- deze hier gebruikt dezelfde gedeelde `VeyraCard`-glaslook,
// maar met een activeringssignaal dat op elk platform werkt: op tvOS focus, op iOS/macOS de
// ingedrukt-status van de knop zelf. Voor gedeelde UI (zoals Instant Peek) die niet in een
// platform-specifieke target mag hangen.
import SwiftUI

struct VeyraGlassButtonStyle: ButtonStyle {
    var primary = false

    func makeBody(configuration: Configuration) -> some View {
        VeyraGlassButtonLabel(configuration: configuration, primary: primary)
    }
}

private struct VeyraGlassButtonLabel: View {
    let configuration: ButtonStyleConfiguration
    let primary: Bool

#if os(tvOS)
    @Environment(\.isFocused) private var isFocused
    private var isActive: Bool { isFocused }
#else
    private var isActive: Bool { configuration.isPressed }
#endif

    var body: some View {
        VeyraCard(primary: primary).apply(
            to: configuration.label,
            isActive: isActive,
            isPressed: configuration.isPressed
        )
        .animation(.easeOut(duration: 0.16), value: isActive)
    }
}
