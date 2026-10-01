// VeyraYourCollectionsSection.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// "Jouw Collecties" op Home (Fase 10 van de uitgebreide Collections-spec, §66/§69/§95): een
// persoonlijke rail met de eigen collecties van de gebruiker, met dezelfde `VeyraCollectionCard`
// als op het "Jouw Collecties"-browserscherm (spec §7: "one collection = one artwork identity" --
// zelfde kaart-component, geen aparte Home-variant). Home bouwt hier GEEN eigen collection-
// datalogica voor (spec §95): dit leest rechtstreeks uit `VeyraCollectionStore`/
// `VeyraCollectionMetadataResolver`, exact zoals de Collections-browser en Continue-sectie dat
// al doen.
//
// Artwork via `VeyraCollectionArtworkResolver` (spec §7/§8) -- zelfde centrale identiteit als de
// browser/Detail/Continue-sectie; backdrop van het meest prominente item dient alleen als fallback.
//
// Spec §68: geen lege shelf -- deze sectie toont zichzelf niet als de gebruiker nog geen eigen
// collecties heeft.

import SwiftUI

struct VeyraYourCollectionsSection: View {
    @ObservedObject private var store = VeyraCollectionStore.shared
    @State private var resolvedByCollection: [VeyraCollection.ID: [VeyraResolvedCollectionItem]] = [:]
    @State private var selected: VeyraCollection?
    @State private var showBrowser = false

    var body: some View {
        if !store.collections.isEmpty {
            // Zelfde titelstijl + afstand tot kaarten als "Voor jou" (VeyraMosaicSection).
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("JOUW COLLECTIES")
                        .font(.system(size: headerSize, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(VeyraColors.cyan.opacity(0.85))
                    Spacer()
                    Button("Bekijk alles") { showBrowser = true }
                        .font(.system(size: headerSize, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .buttonStyle(.plain)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: gap) {
                        ForEach(store.collections) { collection in
                            Button {
                                selected = collection
                            } label: {
                                VeyraCollectionCard(title: collection.name, subtitle: subtitle(for: collection),
                                                    artworkURL: artworkURL(for: collection),
                                                    artworkPosition: collection.artworkPosition,
                                                    sizeOverride: cardSize,
                                                    clearLogoURL: VeyraCollectionClearLogoResolver.resolvedURL(for: collection))
                            }
                            #if os(tvOS)
                            .buttonStyle(VeyraStreamingTileStyle())
                            #else
                            .buttonStyle(.plain)
                            #endif
                        }
                    }
                    // Ruimte voor de focus-vergroting/gloed (spec §5) -- anders clipt de
                    // ScrollView de kaders van de gefocuste kaart af. Verticale marge zelfde als
                    // "Voor jou" (12pt) zodat beide rails evenveel afstand tot hun titel hebben.
                    .padding(.vertical, 12)
                    .padding(.horizontal, cardInset)
                }
                #if os(tvOS)
                .scrollClipDisabled()
                #endif
            }
            .task(id: store.collections) { await loadAll() }
            .navigationDestination(item: $selected) { collection in
                VeyraCollectionDetailView(source: .own(collection.id))
            }
            .navigationDestination(isPresented: $showBrowser) {
                VeyraCollectionsBrowserView()
            }
        }
    }

    private func subtitle(for collection: VeyraCollection) -> String {
        collection.items.count == 1 ? "1 film" : "\(collection.items.count) films"
    }

    // Spec §7: één artwork-identiteit per collectie -- zelfde resolver als browser/Detail/Continue.
    private func artworkURL(for collection: VeyraCollection) -> URL? {
        VeyraCollectionArtworkResolver.resolvedURL(for: collection, fallback: resolvedByCollection[collection.id]?.first?.media.backdropURL)
    }

    // Alleen fallback-backdrop nodig (geen volledige collectie-weergave hier) -- resolve dus
    // enkel het eerste item van collecties die nog geen eigen fanart hebben. Zonder dit resolvede
    // elke rail op Home onnodig ALLE films van ALLE collecties tegelijk, wat bij veel collecties
    // de tvOS-app liet vasthangen bij het opstarten.
    private func loadAll() async {
        var result: [VeyraCollection.ID: [VeyraResolvedCollectionItem]] = [:]
        await withTaskGroup(of: (VeyraCollection.ID, [VeyraResolvedCollectionItem]).self) { group in
            for collection in store.collections where collection.artworkReference == nil && !collection.items.isEmpty {
                group.addTask { (collection.id, await VeyraCollectionMetadataResolver.resolve(Array(collection.items.prefix(1)))) }
            }
            for await (id, items) in group { result[id] = items }
        }
        resolvedByCollection = result
    }

    #if os(tvOS)
    private let headerSize: CGFloat = 20
    private let gap: CGFloat = 28
    private let cardInset: CGFloat = 16
    private let cardSize: CGSize? = CGSize(width: 400, height: 232)
    #else
    private let headerSize: CGFloat = 12
    private let gap: CGFloat = 12
    private let cardInset: CGFloat = 8
    private let cardSize: CGSize? = nil
    #endif
}
