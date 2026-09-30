// VeyraDiscoveryFlow.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// "Discovery Flow": de Trending-plank uit het Home Visual System-spec (Stap 9).
// Eén horizontale rij waarin het gefocuste/geselecteerde item promoveert naar een
// grote, filmische tegel (backdrop + clearlogo + jaar/type, niet te veel tekst),
// terwijl de buren als compacte tegels ernaast blijven staan -- op focus-wissel
// (tvOS) of tik (iOS/iPadOS/macOS) schuift de nieuwe grote tegel op zijn plek in,
// net als in het spec-diagram: "1 BIG -> 2 -> 3" wordt bij focus op 2 "1 <- 2 BIG -> 3".
// Bewust GEEN schermvullende achtergrondwissel -- de achtergrond blijft alleen
// binnen deze plank (spec: "Alleen binnen shelf. Geen full-screen backdrop wissel.").
// Hergebruikt `HeroSpotlightItem`/`HeroSpotlightLoader` (zie VeyraHeroSpotlightModel.swift) --
// zelfde ophaal-/clearlogo-laag als de Home-hero, gewoon een eigen, vaste
// (niet-instelbare) Trending-bron i.p.v. de door de gebruiker gekozen hero-bron.

import SwiftUI

struct VeyraDiscoveryFlow: View {
    let title: String
    let items: [HeroSpotlightItem]

    @Environment(\.openMediaDetail) private var openMediaDetail
    #if os(tvOS)
    @FocusState private var focusedID: String?
    #endif
    @State private var tappedID: String?

    private var bigID: String? {
        #if os(tvOS)
        focusedID ?? items.first?.id
        #else
        tappedID ?? items.first?.id
        #endif
    }

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.system(size: headerSize, weight: .heavy, design: .rounded))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundStyle(VeyraHomeStyle.cyan.opacity(0.85))

                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .center, spacing: cardGap) {
                            ForEach(items) { item in
                                card(item, big: item.id == bigID)
                                    .id(item.id)
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 12)
                    }
                    .scrollClipDisabled()
                    .onChange(of: bigID) { _, newValue in
                        guard let newValue else { return }
                        withAnimation(.easeOut(duration: 0.35)) { proxy.scrollTo(newValue, anchor: .center) }
                    }
                }
            }
        }
    }

    // MARK: - Eén tegel

    @ViewBuilder
    private func card(_ item: HeroSpotlightItem, big: Bool) -> some View {
        #if os(tvOS)
        Button { openMediaDetail(item.mediaItem) } label: {
            cardContent(item, big: big)
        }
        .buttonStyle(VeyraStreamingTileStyle())
        .focused($focusedID, equals: item.id)
        #else
        NavigationLink {
            ShelfItemDestination(item: item.mediaItem)
        } label: {
            cardContent(item, big: big)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture().onEnded { tappedID = item.id })
        #endif
    }

    @ViewBuilder
    private func cardContent(_ item: HeroSpotlightItem, big: Bool) -> some View {
        ZStack(alignment: .bottomLeading) {
            GeometryReader { geo in
                AsyncImage(url: item.backdropURL) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        VeyraHomeStyle.ink
                    }
                }
                .transition(.opacity)
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
            }

            if big {
                LinearGradient(colors: [.black.opacity(0.85), .black.opacity(0.2), .clear],
                               startPoint: .bottom, endPoint: .center)
                info(item)
                    .padding(cardPaddingH)
            } else {
                // Compacte buurtegel: enkel gedimd, geen eigen tekst -- die komt pas
                // wanneer dit item zelf de grote tegel wordt (spec §29/§30). Sommige
                // backdrops zijn zelf erg licht/wit -- 0.55 i.p.v. 0.38 zodat de rij
                // ook dan donker genoeg blijft (Veyra-stijl blijft dominant).
                Color.black.opacity(0.55)
            }
        }
        .frame(width: big ? bigWidth : smallWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(big ? VeyraColors.cyan.opacity(0.6) : .clear, lineWidth: 2)
        )
        .shadow(color: .black.opacity(big ? 0.35 : 0), radius: big ? 16 : 0, y: big ? 8 : 0)
        .animation(.easeOut(duration: 0.3), value: big)
    }

    @ViewBuilder
    private func info(_ item: HeroSpotlightItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let logoURL = item.logoURL {
                AsyncImage(url: logoURL) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFit()
                    }
                }
                .frame(maxWidth: logoMaxWidth, maxHeight: logoMaxHeight, alignment: .leading)
            } else {
                Text(item.title)
                    .font(.system(size: titleSize, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }
            // Niet te veel tekst (spec §30): jaar/type, plus hooguit één extra metadata-regel.
            Text(metaLine(item))
                .font(.system(size: metaSize, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
        }
    }

    private func metaLine(_ item: HeroSpotlightItem) -> String {
        var parts: [String] = []
        if let year = item.year { parts.append(year) }
        parts.append(item.isMovie ? "Film" : "Serie")
        if let genre = item.genre { parts.append(genre) }
        return parts.joined(separator: " · ")
    }

    // Maten -- tvOS 10-voet-UI, iOS/iPadOS/macOS compacter van dichtbij bekeken
    // (zelfde onderscheid als `VeyraContextRibbon.Metrics`).
    #if os(tvOS)
    private let headerSize: CGFloat = 19
    private let cardGap: CGFloat = 20
    private let bigWidth: CGFloat = 640
    private let smallWidth: CGFloat = 170
    private let cardHeight: CGFloat = 360
    private let cardPaddingH: CGFloat = 28
    private let logoMaxWidth: CGFloat = 320
    private let logoMaxHeight: CGFloat = 90
    private let titleSize: CGFloat = 32
    private let metaSize: CGFloat = 20
    #else
    private let headerSize: CGFloat = 13
    private let cardGap: CGFloat = 12
    private let bigWidth: CGFloat = 360
    private let smallWidth: CGFloat = 96
    private let cardHeight: CGFloat = 202
    private let cardPaddingH: CGFloat = 16
    private let logoMaxWidth: CGFloat = 180
    private let logoMaxHeight: CGFloat = 48
    private let titleSize: CGFloat = 17
    private let metaSize: CGFloat = 12
    #endif
}
