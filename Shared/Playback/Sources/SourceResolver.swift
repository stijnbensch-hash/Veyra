import Foundation

// MARK: - Bron met addon-identiteit

struct ResolvedSource:
    Identifiable,
    Hashable
{
    let source: PlayableSource

    /// Naam van de addon/provider waaronder deze bron
    /// in SourceSelectionView gegroepeerd wordt.
    ///
    /// Voor een addon komt deze naam uit AddonManifest.name.
    /// Voor IPTV gebruiken we "IPTV".
    let originName: String

    var id: UUID {
        source.id
    }
}

// MARK: - Optioneel protocol
//
// Dit blijft bestaan zodat een provider die dit protocol
// al gebruikt gewoon blijft compileren.
//
// SourceResolver gebruikt de originName hiervan bewust NIET
// voor de addonfilters. De naam van het addon-manifest is
// daarvoor leidend.

protocol ResolvedMediaSourceProvider:
    MediaSourceProvider
{
    func resolvedSources(
        for item: MediaItem
    ) async throws -> [ResolvedSource]
}

// MARK: - Resolver

struct SourceResolver {
    private let addonRegistry:
        AddonRegistry

    private let iptvProvider:
        IPTVVODSourceProvider

    private let mediaServerStore:
        MediaServerStore

    init(
        addonRegistry:
            AddonRegistry = AddonRegistry(),
        iptvProvider:
            IPTVVODSourceProvider =
                IPTVVODSourceProvider(),
        mediaServerStore:
            MediaServerStore =
                MediaServerStore()
    ) {
        self.addonRegistry =
            addonRegistry

        self.iptvProvider =
            iptvProvider

        self.mediaServerStore =
            mediaServerStore
    }

    // MARK: - Alle bronnen

    func sources(
        for item: MediaItem
    ) async -> [PlayableSource] {
        // Addons, IPTV en mediaservers zijn onafhankelijke bronnen — parallel
        // bevragen in plaats van na elkaar scheelt merkbaar in wachttijd.
        async let addonValues = addonSources(for: item)
        async let iptvValues = iptvSources(for: item)
        async let mediaServerValues = jellyfinSources(for: item)

        let (addons, iptv, mediaServers) =
            await (addonValues, iptvValues, mediaServerValues)

        guard
            !Task.isCancelled
        else {
            return []
        }

        return Self
            .deduplicated(
                addons
                    + iptv
                    + mediaServers
            )
            .map(\.source)
    }

    // MARK: - Addons

    func addonSources(
        for item: MediaItem
    ) async -> [ResolvedSource] {
        let registrations =
            addonRegistry.registeredProviders()

        guard !registrations.isEmpty else { return [] }

        // Elke addon apart bevragen kost een eigen netwerk-roundtrip; dat
        // parallel doen (in plaats van op zijn beurt) is de belangrijkste
        // winst voor "bronnen zoeken" bij meerdere geïnstalleerde addons.
        let result = await withTaskGroup(
            of: [ResolvedSource].self
        ) { group -> [ResolvedSource] in
            for registration in registrations {
                group.addTask {
                    guard !Task.isCancelled else { return [] }

                    let provider =
                        registration.provider

                    let addonName =
                        Self.cleanName(
                            registration.addonName
                        )
                        ?? provider.name

                    do {
                        let values =
                            try await provider
                                .sources(
                                    for: item
                                )

                        // BELANGRIJK:
                        //
                        // Alle streams die deze addon teruggeeft
                        // krijgen DEZELFDE originName.
                        //
                        // We gebruiken dus NIET stream.name.
                        return values.map { source in
                            ResolvedSource(
                                source:
                                    source,
                                originName:
                                    addonName
                            )
                        }
                    } catch {
                        // Een mislukte addon blokkeert
                        // de overige addons niet.
                        return []
                    }
                }
            }

            var all: [ResolvedSource] = []
            for await values in group {
                all.append(contentsOf: values)
            }
            return all
        }

        return Self
            .deduplicated(
                result
            )
    }

    // MARK: - IPTV

    func iptvSources(
        for item: MediaItem
    ) async -> [ResolvedSource] {
        do {
            try Task
                .checkCancellation()

            let values =
                try await iptvProvider
                    .sources(
                        for: item
                    )

            return Self
                .deduplicated(
                    values.map { source in
                        ResolvedSource(
                            source:
                                source,
                            originName:
                                "IPTV"
                        )
                    }
                )

        } catch is CancellationError {
            return []

        } catch {
            return []
        }
    }

    // MARK: - Mediaservers (Jellyfin)

    func jellyfinSources(
        for item: MediaItem
    ) async -> [ResolvedSource] {
        let accounts =
            mediaServerStore
                .load()
                .filter {
                    $0.kind == .jellyfin
                }

        guard !accounts.isEmpty else {
            return []
        }

        // Meerdere gekoppelde Jellyfin-servers ook parallel bevragen, om
        // dezelfde reden als bij de addons hierboven.
        let result = await withTaskGroup(
            of: [ResolvedSource].self
        ) { group -> [ResolvedSource] in
            for account in accounts {
                group.addTask {
                    guard !Task.isCancelled else { return [] }

                    let provider =
                        JellyfinSourceProvider(
                            account: account
                        )

                    do {
                        return try await provider
                            .resolvedSources(
                                for: item
                            )
                    } catch {
                        // Een mediaserver die niet bereikbaar is
                        // blokkeert de overige bronnen niet.
                        return []
                    }
                }
            }

            var all: [ResolvedSource] = []
            for await values in group {
                all.append(contentsOf: values)
            }
            return all
        }

        return Self
            .deduplicated(
                result
            )
    }

    // MARK: - Deduplication

    static func deduplicated(
        _ values:
            [ResolvedSource]
    ) -> [ResolvedSource] {
        var seen =
            Set<String>()

        var result:
            [ResolvedSource] = []

        for value in values {
            let key =
                value.source
                    .url
                    .absoluteString

            guard
                seen.insert(
                    key
                ).inserted
            else {
                continue
            }

            result.append(
                value
            )
        }

        return result
    }

    // MARK: - Helpers

    private static func cleanName(
        _ value: String?
    ) -> String? {
        guard
            let value
        else {
            return nil
        }

        let cleaned =
            value.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        return
            cleaned.isEmpty
                ? nil
                : cleaned
    }
}
