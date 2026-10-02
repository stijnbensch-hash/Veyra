// VeyraContinueCollectionsSection.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// "Verder met je collecties" (Fase 8, spec §31/§32): een slimme sectie op basis van bestaande
// watch-state -- toont enkel eigen collecties met minstens één bekeken/gestarte film EN minstens
// één nog niet voltooide film (spec §31). Reageert onmiddellijk op Trakt-wijzigingen (zelfde
// `.veyraTraktHistoryDidChange`-notificatie als de rest van Home, zie TraktStore). Nog NIET in
// Home geïntegreerd -- dat is Fase 9; dit is enkel het component zelf, voorlopig zichtbaar op het
// "Jouw Collecties"-scherm.

import SwiftUI

struct VeyraContinueCollectionsSection: View {
    @ObservedObject private var store = VeyraCollectionStore.shared
    @ObservedObject private var traktStore = TraktStore.shared
    @State private var resolvedByCollection: [VeyraCollection.ID: [VeyraResolvedCollectionItem]] = [:]
    @State private var selected: VeyraCollection?

    private var candidates: [(collection: VeyraCollection, items: [VeyraResolvedCollectionItem])] {
        store.collections.compactMap { collection in
            guard let items = resolvedByCollection[collection.id], !items.isEmpty else { return nil }
            let watchedCount = items.filter { traktStore.isWatched($0.media) }.count
            // Spec §31: minstens één bekeken/gestart EN minstens één nog niet voltooid.
            guard watchedCount > 0, watchedCount < items.count else { return nil }
            return (collection, items)
        }
    }

    var body: some View {
        if !candidates.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("VERDER MET JE COLLECTIES")
                    .font(.system(size: headerSize, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(VeyraColors.cyan.opacity(0.85))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: gap) {
                        ForEach(candidates, id: \.collection.id) { pair in
                            Button {
                                selected = pair.collection
                            } label: {
                                card(pair.collection, pair.items)
                            }
                            #if os(tvOS)
                            .buttonStyle(VeyraStreamingTileStyle())
                            #else
                            .buttonStyle(.plain)
                            #endif
                        }
                    }
                    // Ruimte voor de focus-vergroting/gloed -- anders clipt de ScrollView de
                    // kaders van de gefocuste kaart af.
                    .padding(.vertical, cardInset)
                    .padding(.horizontal, cardInset)
                }
                #if os(tvOS)
                .scrollClipDisabled()
                #endif
            }
            .task(id: store.collections) { await loadAll() }
            .onReceive(NotificationCenter.default.publisher(for: .veyraTraktHistoryDidChange)) { _ in
                Task { await loadAll() }
            }
            .navigationDestination(item: $selected) { collection in
                VeyraCollectionDetailView(source: .own(collection.id))
            }
        }
    }

    private func loadAll() async {
        var result: [VeyraCollection.ID: [VeyraResolvedCollectionItem]] = [:]
        await withTaskGroup(of: (VeyraCollection.ID, [VeyraResolvedCollectionItem]).self) { group in
            for collection in store.collections where !collection.items.isEmpty {
                group.addTask { (collection.id, await VeyraCollectionMetadataResolver.resolve(collection.items)) }
            }
            for await (id, items) in group { result[id] = items }
        }
        resolvedByCollection = result
    }

    // MARK: - Continue Collection card (spec §32)

    @ViewBuilder
    private func card(_ collection: VeyraCollection, _ items: [VeyraResolvedCollectionItem]) -> some View {
        let watchedCount = items.filter { traktStore.isWatched($0.media) }.count
        let next = items.first { !traktStore.isWatched($0.media) }
        let fraction = items.isEmpty ? 0 : CGFloat(watchedCount) / CGFloat(items.count)

        let artworkURL = VeyraCollectionArtworkResolver.resolvedURL(for: collection, fallback: items.first?.media.backdropURL)
        #if os(tvOS)
        ContinueCollectionFocusRing {
            cardContent(collection, watchedCount: watchedCount, total: items.count, fraction: fraction, next: next, artworkURL: artworkURL)
        }
        #else
        cardContent(collection, watchedCount: watchedCount, total: items.count, fraction: fraction, next: next, artworkURL: artworkURL)
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(VeyraFrame.resting, lineWidth: 1.5))
        #endif
    }

    @ViewBuilder
    private func cardContent(_ collection: VeyraCollection, watchedCount: Int, total: Int, fraction: CGFloat,
                             next: VeyraResolvedCollectionItem?, artworkURL: URL?) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let artworkURL {
                GeometryReader { geo in
                    VeyraAsyncImage(url: artworkURL) { phase in
                        if case .success(let image) = phase {
                            let position = collection.artworkPosition ?? VeyraArtworkPosition()
                            image.resizable().scaledToFill()
                                .scaleEffect(position.zoom)
                                .offset(x: (0.5 - position.x) * geo.size.width, y: (0.5 - position.y) * geo.size.height)
                        } else { Color.clear }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                }
                LinearGradient(colors: [.black.opacity(0.9), .black.opacity(0.55), .black.opacity(0.15)],
                               startPoint: .bottom, endPoint: .top)
            }
            cardText(collection, watchedCount: watchedCount, total: total, fraction: fraction, next: next)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .topTrailing) {
            Circle().fill(VeyraColors.red.opacity(0.55)).frame(width: 8, height: 8).padding(10)
        }
    }

    @ViewBuilder
    private func cardText(_ collection: VeyraCollection, watchedCount: Int, total: Int, fraction: CGFloat,
                          next: VeyraResolvedCollectionItem?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(collection.name.uppercased())
                .font(.system(size: titleSize, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text("\(watchedCount) / \(total) bekeken")
                .font(.system(size: metaSize, weight: .semibold))
                .foregroundStyle(VeyraColors.cyan)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.15))
                    Capsule().fill(VeyraColors.cyan).frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 6)
            if let next {
                Text("Volgende: \(next.media.title)")
                    .font(.system(size: metaSize))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(cardPadding)
        .frame(width: cardWidth, alignment: .leading)
        .background(VeyraColors.surface.opacity(0.4))
    }

    #if os(tvOS)
    private let headerSize: CGFloat = 20
    private let gap: CGFloat = 24
    private let cardWidth: CGFloat = 380
    private let cardPadding: CGFloat = 22
    private let titleSize: CGFloat = 23
    private let metaSize: CGFloat = 17
    private let cardInset: CGFloat = 16
    #else
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isPad: Bool { sizeClass == .regular }
    #else
    private var isPad: Bool { false }
    #endif

    private let headerSize: CGFloat = 12
    private let gap: CGFloat = 12
    private var cardWidth: CGFloat { isPad ? 280 : 220 }
    private var cardPadding: CGFloat { isPad ? 18 : 14 }
    private var titleSize: CGFloat { isPad ? 19 : 15 }
    private var metaSize: CGFloat { isPad ? 15 : 12 }
    private let cardInset: CGFloat = 8
    #endif
}

#if os(tvOS)
/// Zelfde focus-patroon als `MosaicFocusRing` (VeyraMosaicSection.swift): "focused" -> sterkere
/// cyaan gloed/kader (spec §32: "Focused: stronger cyan glow").
private struct ContinueCollectionFocusRing<Content: View>: View {
    @Environment(\.isFocused) private var isFocused
    @ViewBuilder let content: Content
    var body: some View {
        content
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isFocused ? VeyraFrame.active : VeyraFrame.resting, lineWidth: isFocused ? 3 : 1.5))
            .shadow(color: isFocused ? VeyraColors.cyan.opacity(0.4) : .clear, radius: 18)
            .scaleEffect(isFocused ? 1.04 : 1)
            .animation(.easeOut(duration: 0.16), value: isFocused)
    }
}
#endif
