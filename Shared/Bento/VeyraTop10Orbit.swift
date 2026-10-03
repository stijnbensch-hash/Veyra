// VeyraTop10Orbit.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// "Top 10 Orbit" uit het Home Visual System-spec (Stap 15, §55-57) -- de laatste
// sectie op Home. Geen echte 3D-engine (spec §56/§96: "Bouw simpel. Geen echte
// 3D."): dit hergebruikt het al bestaande focus-promotie-idioom (zie
// `VeyraDiscoveryFlow`/`VeyraOnAirSection`) met een rangnummer per tegel en een
// lichte offset/schaal/zIndex/opacity-verschuiving rond de gefocuste tegel om
// een "orbit"-gevoel te suggereren, i.p.v. een zware carrousel-rotatie-animatie
// (spec §57: "Niet draaien als carrousel met zware animatie").
// Data: dezelfde `HeroSpotlightItem`/`HeroSpotlightLoader`-laag als Trending/
// Voor Jou (Top 10-lijst, bv. TMDB/Trakt "populair") -- geen nieuwe bron.

import SwiftUI

struct VeyraTop10Orbit: View {
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

    private var bigIndex: Int {
        items.firstIndex(where: { $0.id == bigID }) ?? 0
    }

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Text(title)
                        .font(.system(size: headerSize, weight: .heavy, design: .rounded))
                        .tracking(2)
                        .textCase(.uppercase)
                        .foregroundStyle(VeyraHomeStyle.cyan.opacity(0.85))
                    VeyraSectionTitleLine()
                }

                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .center, spacing: cardGap) {
                            ForEach(Array(items.prefix(10).enumerated()), id: \.element.id) { index, item in
                                tile(item, rank: index + 1, big: item.id == bigID, distance: index - bigIndex)
                                    .id(item.id)
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 28)
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
    private func tile(_ item: HeroSpotlightItem, rank: Int, big: Bool, distance: Int) -> some View {
        #if os(tvOS)
        Button { openMediaDetail(item.mediaItem) } label: {
            tileContent(item, rank: rank, big: big, distance: distance)
        }
        .buttonStyle(VeyraStreamingTileStyle())
        .focused($focusedID, equals: item.id)
        #else
        NavigationLink {
            ShelfItemDestination(item: item.mediaItem)
        } label: {
            tileContent(item, rank: rank, big: big, distance: distance)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture().onEnded { tappedID = item.id })
        #endif
    }

    /// Lichte, statische verschuiving/schaal per afstand tot de gefocuste tegel --
    /// suggereert een baan ("orbit") rond de #1-tegel zonder echte 3D-transformatie
    /// of carrousel-rotatie (spec §56/§57).
    private func tileContent(_ item: HeroSpotlightItem, rank: Int, big: Bool, distance: Int) -> some View {
        let clampedDistance = max(-2, min(2, distance))
        let scale: CGFloat = big ? 1.0 : (clampedDistance == 0 ? 1.0 : 1.0 - CGFloat(abs(clampedDistance)) * 0.08)
        let verticalOffset: CGFloat = big ? 0 : CGFloat(clampedDistance) * orbitStep
        let opacity: Double = big ? 1.0 : max(0.55, 1.0 - Double(abs(clampedDistance)) * 0.12)

        return ZStack(alignment: .bottomLeading) {
            GeometryReader { geo in
                VeyraAsyncImage(url: item.posterURL ?? item.backdropURL) { phase in
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

            LinearGradient(colors: [.black.opacity(0.78), .clear], startPoint: .bottom, endPoint: .center)

            if big {
                Text(item.title)
                    .font(.system(size: titleSize, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .padding(tilePaddingH)
            }
        }
        .frame(width: big ? bigWidth : smallWidth, height: big ? bigHeight : smallHeight)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .topLeading) {
            Text("\(rank)")
                .font(.system(size: rankSize, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, rankPaddingH)
                .padding(.vertical, rankPaddingV)
                .background(.black.opacity(0.55), in: Capsule())
                .padding(rankMargin)
        }
        .scaleEffect(scale)
        .offset(y: verticalOffset)
        .opacity(opacity)
        .zIndex(big ? 10 : Double(10 - abs(clampedDistance)))
        .shadow(color: .black.opacity(big ? 0.35 : 0), radius: big ? 16 : 0, y: big ? 8 : 0)
        .animation(.easeOut(duration: 0.3), value: big)
    }

    // Maten -- tvOS 10-voet-UI, iOS/iPadOS/macOS compacter van dichtbij bekeken
    // (zelfde onderscheid als `VeyraDiscoveryFlow`).
    #if os(tvOS)
    private let headerSize: CGFloat = 19
    private let cardGap: CGFloat = 20
    private let bigWidth: CGFloat = 300
    private let bigHeight: CGFloat = 420
    // Kleiner verschil met de uitgelichte tegel (was 180/252, duidelijk kleiner) --
    // de uitgelichte tegel zelf blijft exact hetzelfde formaat (`bigWidth`/`bigHeight`
    // veranderen niet), de buren worden groter zodat de sprong minder groot aanvoelt.
    private let smallWidth: CGFloat = 240
    private let smallHeight: CGFloat = 336
    private let titleSize: CGFloat = 22
    private let tilePaddingH: CGFloat = 14
    private let rankSize: CGFloat = 20
    private let rankPaddingH: CGFloat = 12
    private let rankPaddingV: CGFloat = 4
    private let rankMargin: CGFloat = 10
    private let orbitStep: CGFloat = 16
    #else
    private let headerSize: CGFloat = 13
    private let cardGap: CGFloat = 12
    private let bigWidth: CGFloat = 160
    private let bigHeight: CGFloat = 224
    private let smallWidth: CGFloat = 128
    private let smallHeight: CGFloat = 179
    private let titleSize: CGFloat = 14
    private let tilePaddingH: CGFloat = 8
    private let rankSize: CGFloat = 13
    private let rankPaddingH: CGFloat = 8
    private let rankPaddingV: CGFloat = 2
    private let rankMargin: CGFloat = 6
    private let orbitStep: CGFloat = 10
    #endif
}
