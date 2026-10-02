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
            // Zelfde titelstijl + afstand tot kader als "Binnenkort"/"Verder kijken" (bentoTop).
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.system(size: headerSize, weight: .bold))
                    .tracking(1.5)
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
                VeyraAsyncImage(url: item.backdropURL) { phase in
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
                // Compacte buurtegel: gedimd, met enkel een klein clearlogo (of titel als
                // terugval) onderaan -- zonder metadata-regel, dat blijft voorbehouden aan de
                // grote tegel (spec §29/§30). Sommige backdrops zijn zelf erg licht/wit --
                // 0.55 i.p.v. 0.38 zodat de rij ook dan donker genoeg blijft.
                Color.black.opacity(0.55)
                LinearGradient(colors: [.black.opacity(0.75), .clear],
                               startPoint: .bottom, endPoint: .center)
                smallInfo(item)
                    .padding(smallCardPaddingH)
            }
        }
        .frame(width: big ? bigWidth : smallWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        // Zelfde cyaan/rode Veyra-kaderstijl als de rest van Home (VeyraFrame) i.p.v. enkel
        // effen cyaan op de grote tegel en helemaal geen rand op de kleine buurtegels.
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(big ? VeyraFrame.active : VeyraFrame.resting, lineWidth: big ? 2 : 1.5)
        )
        .shadow(color: .black.opacity(big ? 0.35 : 0), radius: big ? 16 : 0, y: big ? 8 : 0)
        .animation(.easeOut(duration: 0.3), value: big)
    }

    @ViewBuilder
    private func info(_ item: HeroSpotlightItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let logoURL = item.logoURL {
                VeyraAsyncImage(url: logoURL) { phase in
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

    @ViewBuilder
    private func smallInfo(_ item: HeroSpotlightItem) -> some View {
        if let logoURL = item.logoURL {
            VeyraAsyncImage(url: logoURL) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFit()
                } else {
                    smallTitleText(item)
                }
            }
            .frame(maxWidth: smallLogoMaxWidth, maxHeight: smallLogoMaxHeight, alignment: .leading)
        } else {
            smallTitleText(item)
        }
    }

    private func smallTitleText(_ item: HeroSpotlightItem) -> some View {
        Text(item.title)
            .font(.system(size: smallTitleSize, weight: .bold))
            .foregroundStyle(.white)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
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
    private let headerSize: CGFloat = 20
    private let cardGap: CGFloat = 20
    private let bigWidth: CGFloat = 640
    private let smallWidth: CGFloat = 170
    private let cardHeight: CGFloat = 360
    private let cardPaddingH: CGFloat = 28
    private let logoMaxWidth: CGFloat = 320
    private let logoMaxHeight: CGFloat = 90
    private let titleSize: CGFloat = 32
    private let metaSize: CGFloat = 20
    private let smallCardPaddingH: CGFloat = 12
    private let smallLogoMaxWidth: CGFloat = 146
    private let smallLogoMaxHeight: CGFloat = 54
    private let smallTitleSize: CGFloat = 15
    #else
    private let headerSize: CGFloat = 12
    private let cardGap: CGFloat = 12
    private let bigWidth: CGFloat = 360
    private let smallWidth: CGFloat = 96
    private let cardHeight: CGFloat = 202
    private let cardPaddingH: CGFloat = 16
    private let logoMaxWidth: CGFloat = 180
    private let logoMaxHeight: CGFloat = 48
    private let titleSize: CGFloat = 17
    private let metaSize: CGFloat = 12
    private let smallCardPaddingH: CGFloat = 8
    private let smallLogoMaxWidth: CGFloat = 80
    private let smallLogoMaxHeight: CGFloat = 28
    private let smallTitleSize: CGFloat = 10
    #endif
}
