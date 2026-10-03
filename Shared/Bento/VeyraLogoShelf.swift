// VeyraLogoShelf.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// "Logo Shelf": de nieuwe, rustige stijl voor de "Streamingdiensten"-rij uit het
// Home Visual System-spec (Stap 11) -- gewoon de woordmerken op een rij, geen
// posters en geen voor-elke-kaart-ingekleurd vlak meer (spec §36/§37). Bij focus
// een zachte gloed/gradient in de merkkleur i.p.v. de merkkleur volledig over de
// hele kaart (spec §38: "Veyra-stijl blijft dominant"). Zelfde data/actie als
// voorheen (`BentoCatalog`/`onOpenCatalog`, zie `VeyraBentoStreamingContent` die
// dit vervangt) -- enkel de presentatie is nieuw, geen nieuwe navigatie (spec §39).
// Volledige woordmerken worden lokaal gebundeld; overige diensten gebruiken de
// bestaande `BentoCatalog`-metadata. Eigen logo's houden voorrang.

import SwiftUI

private struct VeyraStreamingHighlightedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var veyraStreamingHighlighted: Bool {
        get { self[VeyraStreamingHighlightedKey.self] }
        set { self[VeyraStreamingHighlightedKey.self] = newValue }
    }
}

/// Touch/hover counterpart of the Apple TV's remote focus, without an opaque button fill.
struct VeyraStreamingInteractionStyle: ButtonStyle {
    @State private var hovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .environment(\.veyraStreamingHighlighted, configuration.isPressed || hovered)
            #if os(macOS)
            .onHover { hovered = $0 }
            #endif
    }
}

struct VeyraLogoShelfTile: View {
    let name: String
    let iconURL: URL?
    let wideURL: URL?
    let brand: UInt32?
    var compact = false
    /// Eigen logo van de gebruiker: getoond zoals het is.
    var customURL: URL? = nil
    /// Compacte dienstenrij direct onder de navigatie op ieder platform.
    var ribbon = false

    @Environment(\.isFocused) private var isFocused
    @Environment(\.veyraStreamingHighlighted) private var isInteracting

    private var highlighted: Bool { isFocused || isInteracting }

    private var streamingBrand: VeyraStreamingBrand? { VeyraStreamingBrand.named(name) }

    private var tint: Color {
        guard let brand = streamingBrand?.color ?? brand else { return VeyraColors.cyan }
        return Color(red: Double((brand >> 16) & 0xFF) / 255,
                     green: Double((brand >> 8) & 0xFF) / 255,
                     blue: Double(brand & 0xFF) / 255)
    }

    private var wordmarkColor: Color { highlighted ? tint : .white.opacity(0.92) }

    var body: some View {
        let radius: CGFloat = ribbon ? 14 : (compact ? 16 : 26)
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack {
            // Rustige, neutrale achtergrond -- geen brandkleur-vlak meer. Enkel bij
            // focus een zachte gloed in de merkkleur (spec §38) -- bewust BEHOUDEN
            // (i.p.v. overal cyaan): de merkherkenning van elke streamingdienst is
            // hier expliciet gewenst, in tegenstelling tot de rest van Home.
            if !ribbon { VeyraColors.surface }
            if highlighted {
                RadialGradient(colors: [tint.opacity(0.32), .clear], center: .center,
                               startRadius: 0, endRadius: ribbon || compact ? 80 : 160)
            }
            content
                .padding(.horizontal, ribbon || compact ? 12 : 26)
                .padding(.vertical, ribbon ? 10 : (compact ? 12 : 26))
        }
        .frame(maxWidth: ribbon ? .infinity : nil, maxHeight: ribbon ? .infinity : nil)
        .clipShape(shape)
        .overlay {
            // `tint.opacity(...)` is een Color, `VeyraFrame.resting` een LinearGradient --
            // via AnyShapeStyle verenigd zodat de ternary compileert.
            shape.strokeBorder(highlighted ? AnyShapeStyle(tint.opacity(0.85)) : AnyShapeStyle(VeyraFrame.resting),
                                lineWidth: highlighted ? 3 : (ribbon ? 1.5 : 1))
        }
        .scaleEffect(highlighted ? 1.03 : 1)
        .shadow(color: highlighted ? tint.opacity(0.28) : .clear, radius: ribbon ? 8 : 20)
        .animation(.easeOut(duration: 0.16), value: highlighted)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
    }

    @ViewBuilder
    private var content: some View {
        if let customURL {
            VeyraAsyncImage(url: customURL, maxPixelSize: ribbon ? 320 : 1024) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                } else {
                    nameLabel
                }
            }
        } else if let streamingBrand {
            VeyraStreamingWordmark(brand: streamingBrand, color: wordmarkColor)
        } else if let wideURL {
            VeyraAsyncImage(url: wideURL, maxPixelSize: ribbon ? 320 : 1024) { phase in
                if let image = phase.image {
                    image.renderingMode(.template).resizable().scaledToFit().foregroundStyle(wordmarkColor)
                } else {
                    nameLabel
                }
            }
        } else {
            HStack(spacing: ribbon || compact ? 8 : 14) {
                if let iconURL {
                    VeyraAsyncImage(url: iconURL, maxPixelSize: ribbon ? 96 : 1024) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() } else { Color.white.opacity(0.1) }
                    }
                    .frame(width: ribbon ? 30 : (compact ? 34 : 64), height: ribbon ? 30 : (compact ? 34 : 64))
                    .clipShape(RoundedRectangle(cornerRadius: ribbon || compact ? 8 : 14, style: .continuous))
                }
                nameLabel
            }
        }
    }

    private var nameLabel: some View {
        Text(name)
            .font(.system(size: ribbon ? 21 : (compact ? 14 : 26), weight: ribbon ? .semibold : .bold))
            .foregroundStyle(.white)
            .lineLimit(2)
            .minimumScaleFactor(ribbon ? 0.9 : 0.6)
            .multilineTextAlignment(.leading)
    }
}
