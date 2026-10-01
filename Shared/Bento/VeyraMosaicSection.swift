// VeyraMosaicSection.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// "Dynamic Mosaic": de "Voor Jou"-plank uit het Home Visual System-spec (Stap 10).
// Items in groepen van 4, elke groep als collage: één grote tegel + twee kleine
// ernaast + één brede eronder (spec §33). Groepen scrollen horizontaal na elkaar,
// max. 4 items per groep -- geen gigantisch raster (spec §34).
// De grote tegel is altijd het EERSTE item van zijn groep en blijft dat, ongeacht
// focus -- spec §35 vraagt expliciet de stabielste optie i.p.v. een compositie die
// bij elke mini-focus herschikt ("large tile blijft dominant binnen huidige group").
// Data: Trakt-watchlist (film + serie gemixt) via dezelfde HeroSpotlightLoader-laag
// als "Trending" (VeyraDiscoveryFlow.swift) -- vereist een gekoppeld Trakt-account;
// zonder koppeling of te weinig items toont deze sectie gewoon niets.

import SwiftUI

#if os(tvOS)
/// `VeyraStreamingTileStyle` tekent zelf GEEN focusindicator (`.focusEffectDisabled()` zonder
/// vervanging) -- zonder dit wrapje lijkt een tegel hier dus onselecteerbaar, want je ziet nooit
/// welke tegel focus heeft. Zelfde cyaan rand + lichte vergroting als `VeyraTileStyle` elders.
private struct MosaicFocusRing<Content: View>: View {
    @Environment(\.isFocused) private var isFocused
    @ViewBuilder let content: Content

    var body: some View {
        // Zelfde cyaan/rode Veyra-kaderstijl als de rest van Home (VeyraFrame): subtiele
        // gradiëntrand in rust, fel cyaan bij focus -- i.p.v. helemaal geen rand in rust.
        content
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isFocused ? VeyraFrame.active : VeyraFrame.resting, lineWidth: isFocused ? 3 : 1.5))
            .shadow(color: isFocused ? VeyraColors.cyan.opacity(0.35) : .clear, radius: 16)
            .scaleEffect(isFocused ? 1.04 : 1)
            .animation(.easeOut(duration: 0.16), value: isFocused)
    }
}
#endif

struct VeyraMosaicSection: View {
    let title: String
    let items: [HeroSpotlightItem]

    @Environment(\.openMediaDetail) private var openMediaDetail

    // De laatste groep mag KLEINER dan 4 zijn (zie `mosaic(_:)`, die alleen de
    // aanwezige slots tekent) -- een volle groep tot 4 verplichten liet de hele
    // sectie verdwijnen zodra de watchlist (bv. na het afspelen van een item, wat
    // Trakt er automatisch uit kan halen) onder een veelvoud van 4 zakte.
    private var groups: [[HeroSpotlightItem]] {
        guard !items.isEmpty else { return [] }
        return stride(from: 0, to: items.count, by: 4).map {
            Array(items[$0..<min($0 + 4, items.count)])
        }
    }

    var body: some View {
        if !groups.isEmpty {
            // Zelfde titelstijl + afstand tot kader als "Binnenkort"/"Verder kijken" (bentoTop).
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.system(size: headerSize, weight: .bold))
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(VeyraHomeStyle.cyan.opacity(0.85))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: groupGap) {
                        ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                            mosaic(group)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 12)
                }
                .scrollClipDisabled()
            }
        }
    }

    // MARK: - Eén groep (collage van 4)

    @ViewBuilder
    private func mosaic(_ group: [HeroSpotlightItem]) -> some View {
        // Alleen de daadwerkelijk aanwezige slots tekenen -- de laatste groep van een
        // krappe lijst (1-3 items) toont dus gewoon minder tegels i.p.v. helemaal te
        // verdwijnen (zie toelichting bij `groups`).
        HStack(alignment: .top, spacing: tileGap) {
            tile(group[0], width: largeWidth, height: largeHeight, showsTitle: true)
            if group.count > 1 {
                VStack(spacing: tileGap) {
                    if group.count > 2 {
                        HStack(spacing: tileGap) {
                            tile(group[1], width: smallWidth, height: smallHeight, showsTitle: false)
                            tile(group[2], width: smallWidth, height: smallHeight, showsTitle: false)
                        }
                    } else {
                        tile(group[1], width: smallWidth, height: smallHeight, showsTitle: false)
                    }
                    if group.count > 3 {
                        tile(group[3], width: smallWidth * 2 + tileGap, height: smallHeight, showsTitle: false)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func tile(_ item: HeroSpotlightItem, width: CGFloat, height: CGFloat, showsTitle: Bool) -> some View {
        #if os(tvOS)
        Button { openMediaDetail(item.mediaItem) } label: {
            MosaicFocusRing { tileContent(item, width: width, height: height, showsTitle: showsTitle) }
        }
        .buttonStyle(VeyraStreamingTileStyle())
        #else
        NavigationLink {
            ShelfItemDestination(item: item.mediaItem)
        } label: {
            tileContent(item, width: width, height: height, showsTitle: showsTitle)
        }
        .buttonStyle(.plain)
        #endif
    }

    private func tileContent(_ item: HeroSpotlightItem, width: CGFloat, height: CGFloat, showsTitle: Bool) -> some View {
        ZStack(alignment: .bottomLeading) {
            GeometryReader { geo in
                AsyncImage(url: item.backdropURL ?? item.posterURL) { phase in
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
            // Clearlogo (met titeltekst als terugval) op de grote tegel; de kleine tegels
            // krijgen enkel een kleiner clearlogo, net als de compacte buurtegels bij
            // "Trending" -- geen aparte metadata-regel, dat blijft voor de grote tegel elders.
            LinearGradient(colors: [.black.opacity(showsTitle ? 0.82 : 0.7), .clear],
                           startPoint: .bottom, endPoint: .center)
            logo(item, big: showsTitle)
                .padding(showsTitle ? tilePaddingH : smallTilePaddingH)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func logo(_ item: HeroSpotlightItem, big: Bool) -> some View {
        if let logoURL = item.logoURL {
            AsyncImage(url: logoURL) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFit()
                } else {
                    titleText(item, big: big)
                }
            }
            .frame(maxWidth: big ? logoMaxWidth : smallLogoMaxWidth,
                   maxHeight: big ? logoMaxHeight : smallLogoMaxHeight, alignment: .leading)
        } else {
            titleText(item, big: big)
        }
    }

    private func titleText(_ item: HeroSpotlightItem, big: Bool) -> some View {
        Text(item.title)
            .font(.system(size: big ? titleSize : smallTitleSize, weight: .bold))
            .foregroundStyle(.white)
            .lineLimit(2)
    }


    // Maten -- tvOS 10-voet-UI, iOS/iPadOS/macOS compacter van dichtbij bekeken
    // (zelfde onderscheid als `VeyraDiscoveryFlow`/`VeyraContextRibbon.Metrics`).
    #if os(tvOS)
    private let headerSize: CGFloat = 20
    private let groupGap: CGFloat = 32
    private let tileGap: CGFloat = 12
    private let largeWidth: CGFloat = 280
    private let largeHeight: CGFloat = 368
    private let smallWidth: CGFloat = 220
    private let smallHeight: CGFloat = 178
    private let titleSize: CGFloat = 20
    private let tilePaddingH: CGFloat = 14
    private let logoMaxWidth: CGFloat = 220
    private let logoMaxHeight: CGFloat = 70
    private let smallTitleSize: CGFloat = 15
    private let smallTilePaddingH: CGFloat = 10
    private let smallLogoMaxWidth: CGFloat = 160
    private let smallLogoMaxHeight: CGFloat = 46
    #else
    private let headerSize: CGFloat = 12
    private let groupGap: CGFloat = 20
    private let tileGap: CGFloat = 8
    private let largeWidth: CGFloat = 150
    private let largeHeight: CGFloat = 206
    private let smallWidth: CGFloat = 120
    private let smallHeight: CGFloat = 99
    private let titleSize: CGFloat = 13
    private let tilePaddingH: CGFloat = 8
    private let logoMaxWidth: CGFloat = 120
    private let logoMaxHeight: CGFloat = 38
    private let smallTitleSize: CGFloat = 10
    private let smallTilePaddingH: CGFloat = 6
    private let smallLogoMaxWidth: CGFloat = 96
    private let smallLogoMaxHeight: CGFloat = 26
    #endif
}
