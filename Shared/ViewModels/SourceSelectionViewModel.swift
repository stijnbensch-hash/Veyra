import Foundation
import Combine

@MainActor
final class SourceSelectionViewModel: ObservableObject {
    @Published private(set) var sources: [ResolvedSource] = []
    @Published private(set) var isLoadingAddons = false
    @Published private(set) var isLoadingIPTV = false
    @Published private(set) var hasLoaded = false

    private let item: MediaItem
    private let resolver = SourceResolver()
    private var generation = UUID()

    nonisolated init(item: MediaItem) {
        self.item = item
    }

    func loadSources() async {
        let generation = UUID()
        self.generation = generation

        sources = []
        hasLoaded = false
        isLoadingAddons = true
        isLoadingIPTV = false

        // Addons en mediaservers (bv. VeyraHub/Jellyfin) tegelijk ophalen —
        // allebei zijn "origin"-bronnen die als eigen filterknop verschijnen.
        async let addonValuesTask = resolver.addonSources(for: item)
        async let mediaServerValuesTask = resolver.jellyfinSources(for: item)
        let (addonValues, mediaServerValues) = await (addonValuesTask, mediaServerValuesTask)
        guard !Task.isCancelled, self.generation == generation else { return }

        sources = Self.applyOriginOrder(
            SourceResolver.deduplicated(addonValues + mediaServerValues)
        )
        isLoadingAddons = false

        // IPTV voor films én series.
        isLoadingIPTV = true

        let iptvValues = await resolver.iptvSources(for: item)
        guard !Task.isCancelled, self.generation == generation else { return }

        sources = Self.applyOriginOrder(
            SourceResolver.deduplicated(sources + iptvValues)
        )
        isLoadingIPTV = false
        hasLoaded = true
    }

    /// Herschikt bronnen volgens de door de gebruiker ingestelde
    /// bronvolgorde (Instellingen → Bronnen → Bronverschijning →
    /// Bronvolgorde) — bepaalt zowel de volgorde in "Alle" als de volgorde
    /// van de losse filterknoppen (die worden immers uit `sources`
    /// afgeleid, in ditzelfde volgorde).
    private static func applyOriginOrder(_ values: [ResolvedSource]) -> [ResolvedSource] {
        SourceOrderDefaults.sortedByOriginOrder(
            values,
            order: SourceOrderDefaults.loadOriginOrder(),
            originName: { $0.originName },
            isFromHub: { $0.isFromHub }
        )
    }
}
