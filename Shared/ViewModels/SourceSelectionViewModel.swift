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

        let addonValues = await resolver.addonSources(for: item)
        guard !Task.isCancelled, self.generation == generation else { return }

        sources = SourceResolver.deduplicated(addonValues)
        isLoadingAddons = false

        // IPTV voor films én series.
        isLoadingIPTV = true

        let iptvValues = await resolver.iptvSources(for: item)
        guard !Task.isCancelled, self.generation == generation else { return }

        sources = SourceResolver.deduplicated(sources + iptvValues)
        isLoadingIPTV = false
        hasLoaded = true
    }
}
