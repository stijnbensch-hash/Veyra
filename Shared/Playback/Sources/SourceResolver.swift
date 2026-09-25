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
    /// Voor een VeyraHub-bron is dit de naam van de addon zoals VeyraHub
    /// die zelf doorgeeft (bv. "NinjaCentral"), niet de naam van de
    /// VeyraHub-server zelf — zo groepeert deze bron net als een lokaal
    /// geïnstalleerde addon, met `isFromHub` als onderscheid.
    let originName: String

    /// True wanneer deze bron via een VeyraHub-server is opgehaald (i.p.v.
    /// een lokaal geïnstalleerde addon, IPTV, of een "echte" Jellyfin/Emby-
    /// server). SourceSelectionView toont hiervoor een aparte indicator,
    /// zodat een VeyraHub-addon met dezelfde naam als een lokale addon toch
    /// herkenbaar blijft.
    let isFromHub: Bool

    // Expliciete init (i.p.v. op de synthesized memberwise init leunen)
    // zodat `isFromHub` overal een gewone, overschrijfbare parameter met
    // default `false` is — bestaande aanroepen zonder dat argument blijven
    // gewoon compileren.
    init(
        source: PlayableSource,
        originName: String,
        isFromHub: Bool = false
    ) {
        self.source = source
        self.originName = originName
        self.isFromHub = isFromHub
    }

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

        #if DEBUG
        print(
            "[SourceResolver] jellyfinSources: \(accounts.count) account(en) -> \(result.count) native/fallback resultaten vóór dedup (\(result.filter(\.isFromHub).count) via hub)"
        )
        #endif

        return Self
            .deduplicated(
                result
            )
    }

    // MARK: - Deduplication

    // De dedup-sleutel bevat bewust ook `isFromHub`: VeyraHub aggregeert
    // vaak dezelfde addon die ook los geïnstalleerd staat, en levert dan
    // exact dezelfde stream-URL op als de rechtstreekse addon-aanroep. Een
    // eerdere versie liet zo'n botsing de VeyraHub-versie "winnen" en de
    // rechtstreekse addon-kopie vervangen — maar daarmee verdween de
    // gewone addon-knop (en zijn resultaten) helemaal zodra al zijn
    // resultaten toevallig ook via VeyraHub binnenkwamen. Door het
    // hub-onderscheid in de sleutel op te nemen blijven beide versies
    // gewoon naast elkaar bestaan — als twee aparte, apart gestylede
    // knoppen (zie SourceSelectionView) — en dedupt deze functie alleen
    // nog écht identieke dubbels binnen dezelfde bron (zelfde URL, zelfde
    // herkomst).
    static func deduplicated(
        _ values:
            [ResolvedSource]
    ) -> [ResolvedSource] {
        var seenKeys:
            Set<String> = []

        var result:
            [ResolvedSource] = []

        for value in values {
            let key =
                "\(value.source.url.absoluteString)|\(value.isFromHub)"

            guard
                seenKeys.insert(key).inserted
            else {
                continue
            }

            result.append(
                value
            )
        }

        #if DEBUG
        if values.count != result.count || values.contains(where: \.isFromHub) {
            print(
                "[SourceResolver] deduplicated: \(values.count) in -> \(result.count) out (\(result.filter(\.isFromHub).count) via hub, \(values.filter(\.isFromHub).count) hub in input)"
            )
        }
        #endif

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
