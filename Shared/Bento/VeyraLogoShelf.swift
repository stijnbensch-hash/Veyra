// VeyraLogoShelf.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// "Logo Shelf": de nieuwe, rustige stijl voor de "Streamingdiensten"-rij uit het
// Home Visual System-spec (Stap 11) -- gewoon de woordmerken op een rij, geen
// posters en geen voor-elke-kaart-ingekleurd vlak meer (spec §36/§37). Bij focus
// een zachte gloed/gradient in de merkkleur i.p.v. de merkkleur volledig over de
// hele kaart (spec §38: "Veyra-stijl blijft dominant"). Zelfde data/actie als
// voorheen (`BentoCatalog`/`onOpenCatalog`, zie `VeyraBentoStreamingContent` die
// dit vervangt) -- enkel de presentatie is nieuw, geen nieuwe navigatie (spec §39).
// Geen hardcoded Netflix-only logica: alle diensten komen uit dezelfde bestaande
// `BentoCatalog`-metadata (naam/logo/woordmerk/merkkleur) als voorheen.

import SwiftUI

struct VeyraLogoShelfTile: View {
    let name: String
    let iconURL: URL?
    let wideURL: URL?
    let brand: UInt32?
    var compact = false
    /// Eigen logo van de gebruiker: getoond zoals het is.
    var customURL: URL? = nil

    @Environment(\.isFocused) private var isFocused

    private var tint: Color {
        guard let brand else { return VeyraColors.cyan }
        return Color(red: Double((brand >> 16) & 0xFF) / 255,
                     green: Double((brand >> 8) & 0xFF) / 255,
                     blue: Double(brand & 0xFF) / 255)
    }

    var body: some View {
        let radius: CGFloat = compact ? 16 : 26
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack {
            // Rustige, neutrale achtergrond -- geen brandkleur-vlak meer. Enkel bij
            // focus een zachte gloed in de merkkleur (spec §38) -- bewust BEHOUDEN
            // (i.p.v. overal cyaan): de merkherkenning van elke streamingdienst is
            // hier expliciet gewenst, in tegenstelling tot de rest van Home.
            VeyraColors.surface
            if isFocused {
                RadialGradient(colors: [tint.opacity(0.32), .clear], center: .center,
                               startRadius: 0, endRadius: compact ? 80 : 160)
            }
            content
                .padding(compact ? 12 : 26)
        }
        .clipShape(shape)
        .overlay {
            // `tint.opacity(...)` is een Color, `VeyraFrame.resting` een LinearGradient --
            // via AnyShapeStyle verenigd zodat de ternary compileert.
            shape.strokeBorder(isFocused ? AnyShapeStyle(tint.opacity(0.85)) : AnyShapeStyle(VeyraFrame.resting),
                                lineWidth: isFocused ? 3 : 1)
        }
        .scaleEffect(isFocused ? 1.03 : 1)
        .shadow(color: isFocused ? tint.opacity(0.28) : .clear, radius: 20)
        .animation(.easeOut(duration: 0.16), value: isFocused)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
    }

    @ViewBuilder
    private var content: some View {
        if let customURL {
            VeyraAsyncImage(url: customURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                } else {
                    nameLabel
                }
            }
        } else if let wideURL {
            VeyraAsyncImage(url: wideURL) { phase in
                if let image = phase.image {
                    // Wit i.p.v. op de merkkleur -- de achtergrond is nu neutraal,
                    // dus het woordmerk moet zelf zichtbaar blijven ("rustige" Logo Shelf).
                    image.renderingMode(.template).resizable().scaledToFit().foregroundStyle(.white.opacity(0.92))
                } else {
                    nameLabel
                }
            }
        } else {
            HStack(spacing: compact ? 8 : 14) {
                if let iconURL {
                    VeyraAsyncImage(url: iconURL) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() } else { Color.white.opacity(0.1) }
                    }
                    .frame(width: compact ? 34 : 64, height: compact ? 34 : 64)
                    .clipShape(RoundedRectangle(cornerRadius: compact ? 8 : 14, style: .continuous))
                }
                nameLabel
            }
        }
    }

    private var nameLabel: some View {
        Text(name)
            .font(.system(size: compact ? 14 : 26, weight: .bold))
            .foregroundStyle(.white)
            .lineLimit(2)
            .minimumScaleFactor(0.6)
            .multilineTextAlignment(.leading)
    }
}
