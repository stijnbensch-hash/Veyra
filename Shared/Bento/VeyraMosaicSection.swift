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
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.system(size: headerSize, weight: .heavy, design: .rounded))
                    .tracking(2)
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
            tileContent(item, width: width, height: height, showsTitle: showsTitle)
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
            // Titel alleen op de grote tegel -- de kleine tegels blijven puur beeld,
            // net als de compacte buurtegels bij "Trending" (niet te veel tekst).
            if showsTitle {
                LinearGradient(colors: [.black.opacity(0.82), .clear],
                               startPoint: .bottom, endPoint: .center)
                Text(item.title)
                    .font(.system(size: titleSize, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .padding(tilePaddingH)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // Maten -- tvOS 10-voet-UI, iOS/iPadOS/macOS compacter van dichtbij bekeken
    // (zelfde onderscheid als `VeyraDiscoveryFlow`/`VeyraContextRibbon.Metrics`).
    #if os(tvOS)
    private let headerSize: CGFloat = 19
    private let groupGap: CGFloat = 32
    private let tileGap: CGFloat = 12
    private let largeWidth: CGFloat = 280
    private let largeHeight: CGFloat = 368
    private let smallWidth: CGFloat = 220
    private let smallHeight: CGFloat = 178
    private let titleSize: CGFloat = 20
    private let tilePaddingH: CGFloat = 14
    #else
    private let headerSize: CGFloat = 13
    private let groupGap: CGFloat = 20
    private let tileGap: CGFloat = 8
    private let largeWidth: CGFloat = 150
    private let largeHeight: CGFloat = 206
    private let smallWidth: CGFloat = 120
    private let smallHeight: CGFloat = 99
    private let titleSize: CGFloat = 13
    private let tilePaddingH: CGFloat = 8
    #endif
}
