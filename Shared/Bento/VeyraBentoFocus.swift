// VeyraBentoFocus.swift — tvOS 17+
// Focus-waarden en tegelstijl voor de bento-home (tvOS).
// Kader = Veyra-stijl: rustig cyaan->rood verloop, bij focus een heldere ijs/cyaan/rood rand met gloed links en rechts.

#if os(tvOS)
import SwiftUI

enum VeyraHomeFocus: Hashable {
    case cont(String)
    case sport(String)
    case competition(String)
    case channel(String)
    case shelf(String)
    case bento(BentoTile)
}

struct VeyraTileStyle: ButtonStyle {
    var cornerRadius: CGFloat = 30

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        Inner(configuration: configuration, cornerRadius: cornerRadius)
            .focusEffectDisabled()
    }

    private struct Inner: View {
        let configuration: ButtonStyleConfiguration
        let cornerRadius: CGFloat
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            configuration.label
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(.ultraThinMaterial, in: shape)
                .clipShape(shape)
                .overlay(shape.strokeBorder(isFocused ? VeyraFrame.active : VeyraFrame.resting,
                                            lineWidth: isFocused ? 3 : 1.5))
                .shadow(color: isFocused ? VeyraColors.cyan.opacity(0.32) : Color.black.opacity(0.3),
                        radius: isFocused ? 22 : 14, x: isFocused ? -5 : 0, y: isFocused ? 3 : 10)
                .shadow(color: isFocused ? VeyraColors.red.opacity(0.20) : .clear, radius: 22, x: 8, y: 3)
                .scaleEffect(isFocused ? 1.03 : (configuration.isPressed ? 0.98 : 1))
                .zIndex(isFocused ? 1 : 0)
                .animation(.easeOut(duration: 0.16), value: isFocused)
        }
    }
}

#if os(tvOS)
/// Focusstijl voor de capsule-knoppen boven een streamingdienst-catalogus ("Films"/"Series"): geen systeem-witte
/// focuskaart, enkel een lichte vergroting + gloed — de knop tekent zijn eigen achtergrond/rand al (zie `tab(_:)`
/// in `VeyraBentoCatalog.swift`).
struct VeyraTabFocusStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        Inner(configuration: configuration)
            .focusEffectDisabled()
    }

    private struct Inner: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            configuration.label
                .shadow(color: isFocused ? VeyraColors.cyan.opacity(0.30) : .clear, radius: 12, x: -3)
                .shadow(color: isFocused ? VeyraColors.red.opacity(0.20) : .clear, radius: 12, x: 4)
                .scaleEffect(isFocused ? 1.05 : (configuration.isPressed ? 0.97 : 1))
                .animation(.easeOut(duration: 0.16), value: isFocused)
        }
    }
}
#endif

/// Focusstijl voor postercards: GEEN eigen rand/gloed op het hele kaartje (dat zou ook de
/// tekstregels errond omsluiten) -- enkel een lichte vergroting van de hele kaart. Het
/// kader + gloed bij focus tekent `VeyraPosterCard` zelf, uitsluitend rond de poster-
/// afbeelding, via diezelfde `@Environment(\.isFocused)`. `cornerRadius` blijft als
/// parameter bestaan voor bron-compatibiliteit met bestaande aanroepen, maar wordt hier
/// niet meer gebruikt.
struct VeyraPosterFocusStyle: ButtonStyle {
    var cornerRadius: CGFloat = 14

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        Inner(configuration: configuration)
            .focusEffectDisabled()
    }

    private struct Inner: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            configuration.label
                .scaleEffect(isFocused ? 1.05 : (configuration.isPressed ? 0.97 : 1))
                .zIndex(isFocused ? 1 : 0)
                .animation(.easeOut(duration: 0.16), value: isFocused)
        }
    }
}

/// Focus zonder eigen rand: alleen een lichte vergroting. De rand tekent de inhoud zelf (bv. enkel om de banner,
/// niet om de naam eronder) via `@Environment(\.isFocused)`.
struct VeyraBannerFocusStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        Inner(configuration: configuration)
            .focusEffectDisabled()
    }

    private struct Inner: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            configuration.label
                .scaleEffect(isFocused ? 1.05 : (configuration.isPressed ? 0.98 : 1))
                .zIndex(isFocused ? 1 : 0)
                .animation(.easeOut(duration: 0.16), value: isFocused)
        }
    }
}
#endif
