// VeyraCollectionCard.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// Kaart voor "Jouw Collecties" (Fase 4, spec §6/§50/§51/§52): dark glass fill + subtiel cyaan
// kader in rust, feller cyaan kader + gloed + lichte vergroting bij focus (focus = altijd cyaan,
// spec §5), met een klein rood Veyra-accentje in een hoek (spec §52) -- puur decoratief, geen
// focus/selectie-betekenis. Hergebruikt bestaande primitives (`VeyraFrame`, `VeyraColors`)
// i.p.v. een nieuw kadersysteem te verzinnen (spec §4).

import SwiftUI

struct VeyraCollectionCard: View {
    let title: String
    let subtitle: String?
    /// Eén artwork-identiteit per collectie (spec §7), opgelost via
    /// `VeyraCollectionArtworkResolver`. `nil` = Veyra dark/cyan placeholder.
    var artworkURL: URL? = nil
    /// Positionering/crop (spec §59) -- `nil` = gecentreerd, geen extra zoom.
    var artworkPosition: VeyraArtworkPosition? = nil
    var isCreateTile = false
    /// Grotere variant voor rails waar de kaart meer ruimte krijgt (bv. Home "Jouw Collecties"),
    /// `nil` = standaardgrootte voor deze plek/platform.
    var sizeOverride: CGSize? = nil
    /// Expliciet gekozen clearlogo (`VeyraCollectionClearLogoResolver`) -- `nil` = gewoon de
    /// titel-tekst. Bewust GEEN automatische per-kaart TMDB-lookup hier (zie die resolver).
    var clearLogoURL: URL? = nil

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isPad: Bool { sizeOverride == nil && sizeClass == .regular }
    #else
    private var isPad: Bool { false }
    #endif

    private var cardWidth: CGFloat { sizeOverride?.width ?? width }
    private var cardHeight: CGFloat { sizeOverride?.height ?? height }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                background
                if isCreateTile { content.padding(paddingH) }
            }
            .frame(width: cardWidth, height: cardHeight)
            .clipShape(shape)
            .overlay(shape.strokeBorder(VeyraFrame.resting, lineWidth: 1.5))
            .overlay(alignment: .topTrailing) { redAccent }
            .modifier(VeyraCollectionCardFocusEffect())

            // Clearlogo/titel staat ONDER de kaart i.p.v. als overlay erop, met de cyaan
            // meta-tekst (bv. "6 films") ernaast, rechts uitgelijnd op dezelfde regel.
            if !isCreateTile {
                HStack(alignment: .center, spacing: 8) {
                    titleView
                    Spacer(minLength: 8)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: subtitleSize, weight: .medium))
                            .foregroundStyle(VeyraColors.cyan)
                            .lineLimit(1)
                    }
                }
                .frame(width: cardWidth)
            }
        }
    }

    @ViewBuilder
    private var background: some View {
        if isCreateTile {
            VeyraColors.surface
        } else if let artworkURL {
            GeometryReader { geo in
                VeyraAsyncImage(url: artworkURL) { phase in
                    if case .success(let image) = phase {
                        let position = artworkPosition ?? VeyraArtworkPosition()
                        image.resizable().scaledToFill()
                            .scaleEffect(position.zoom)
                            .offset(x: (0.5 - position.x) * geo.size.width, y: (0.5 - position.y) * geo.size.height)
                    } else { placeholder }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        LinearGradient(colors: [VeyraColors.surface, VeyraColors.background],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var content: some View {
        VStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: plusSize, weight: .semibold))
                .foregroundStyle(VeyraColors.cyan)
            Text("Nieuwe collectie")
                .font(.system(size: titleSize, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var titleView: some View {
        if let clearLogoURL {
            VeyraAsyncImage(url: clearLogoURL) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFit()
                        .frame(maxWidth: cardWidth * 0.55, maxHeight: logoMaxHeight, alignment: .leading)
                } else {
                    Text(title)
                        .font(.system(size: titleSize, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
            }
        } else {
            Text(title)
                .font(.system(size: titleSize, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
    }

    /// Klein rood Veyra-accentje in de hoek (spec §52) -- bewust afwezig op de "+ Nieuw"-tegel,
    /// die is neutraal.
    private var redAccent: some View {
        Circle()
            .fill(VeyraColors.red.opacity(isCreateTile ? 0 : 0.55))
            .frame(width: 8, height: 8)
            .padding(12)
            .allowsHitTesting(false)
    }

    #if os(tvOS)
    private let width: CGFloat = 360
    private let height: CGFloat = 210
    private let paddingH: CGFloat = 22
    private let titleSize: CGFloat = 25
    private let subtitleSize: CGFloat = 18
    private let plusSize: CGFloat = 40
    private let logoMaxHeight: CGFloat = 46
    #else
    // Op iPad (regular size class) merkbaar groter dan op iPhone -- zelfde kaart,
    // alleen de maten schalen mee (geen aparte lay-out).
    private var width: CGFloat { isPad ? 230 : 170 }
    private var height: CGFloat { isPad ? 140 : 104 }
    private var paddingH: CGFloat { isPad ? 16 : 12 }
    private var titleSize: CGFloat { isPad ? 19 : 14 }
    private var subtitleSize: CGFloat { isPad ? 15 : 11 }
    private var plusSize: CGFloat { isPad ? 32 : 24 }
    private var logoMaxHeight: CGFloat { isPad ? 36 : 26 }
    #endif

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 16, style: .continuous) }
}

#if os(tvOS)
/// Cyaan kader + lichte vergroting + gloed bij focus -- zelfde taal als `VeyraPosterCard`
/// (focus = altijd cyaan, spec §5).
private struct VeyraCollectionCardFocusEffect: ViewModifier {
    @Environment(\.isFocused) private var isFocused
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(VeyraFrame.active, lineWidth: 3)
                    .opacity(isFocused ? 1 : 0)
            )
            .scaleEffect(isFocused ? 1.04 : 1)
            .shadow(color: isFocused ? VeyraColors.cyan.opacity(0.35) : .clear, radius: 20)
            .animation(.easeOut(duration: 0.16), value: isFocused)
    }
}
#else
private struct VeyraCollectionCardFocusEffect: ViewModifier {
    func body(content: Content) -> some View { content }
}
#endif
