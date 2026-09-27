import Foundation

actor IPTVVODCatalogCache {
    static let shared =
        IPTVVODCatalogCache()

    private struct MovieEntry {
        let loadedAt: Date
        let items: [IPTVVODItem]
    }

    private struct SeriesEntry {
        let loadedAt: Date
        let items: [XtreamSeriesItem]
    }

    private var movieEntries:
        [String: MovieEntry] = [:]

    private var seriesEntries:
        [String: SeriesEntry] = [:]

    private let lifetime:
        TimeInterval = 15 * 60

    func cachedItems(
        providerIdentifier: String
    ) -> [IPTVVODItem]? {
        guard
            let movieEntry = movieEntries[providerIdentifier],
            Date().timeIntervalSince(
                movieEntry.loadedAt
            ) < lifetime
        else {
            return nil
        }

        return movieEntry.items
    }

    func store(
        _ items: [IPTVVODItem],
        providerIdentifier: String
    ) {
        movieEntries[providerIdentifier] =
            MovieEntry(
                loadedAt:
                    Date(),
                items:
                    items
            )
    }

    func cachedSeries(
        providerIdentifier: String
    ) -> [XtreamSeriesItem]? {
        guard
            let seriesEntry = seriesEntries[providerIdentifier],
            Date().timeIntervalSince(
                seriesEntry.loadedAt
            ) < lifetime
        else {
            return nil
        }

        return seriesEntry.items
    }

    func storeSeries(
        _ items: [XtreamSeriesItem],
        providerIdentifier: String
    ) {
        seriesEntries[providerIdentifier] =
            SeriesEntry(
                loadedAt:
                    Date(),
                items:
                    items
            )
    }

    func invalidate() {
        movieEntries.removeAll()
        seriesEntries.removeAll()
    }
}

struct IPTVVODSourceProvider:
    MediaSourceProvider
{
    let name =
        "IPTV VOD"

    private let configurationStore:
        IPTVConfigurationStore

    private let preferencesStore:
        IPTVProviderPreferencesStore

    private let service:
        IPTVService

    private let cache:
        IPTVVODCatalogCache

    init(
        configurationStore:
            IPTVConfigurationStore =
                IPTVConfigurationStore(),
        preferencesStore:
            IPTVProviderPreferencesStore =
                IPTVProviderPreferencesStore(),
        service:
            IPTVService =
                IPTVService(),
        cache:
            IPTVVODCatalogCache =
                .shared
    ) {
        self.configurationStore =
            configurationStore

        self.preferencesStore =
            preferencesStore

        self.service =
            service

        self.cache =
            cache
    }

    func sources(
        for item: MediaItem
    ) async throws -> [PlayableSource] {
        try Task.checkCancellation()

        let providers = SourceOrderDefaults.sortedProviders(
            try configurationStore.loadProviders(),
            order: SourceOrderDefaults.loadIPTVProviderOrder(),
            id: { $0.id }
        )

        // De actieve IPTV-provider bepaalt Live TV, maar de bronkeuze moet
        // VOD van elke ingestelde Xtream-provider kunnen vinden.
        return await withTaskGroup(of: (Int, [PlayableSource]).self) { group in
            for (index, provider) in providers.enumerated() {
                guard case .xtream(let xtreamConfiguration) = provider.configuration else {
                    continue
                }

                group.addTask {
                    do {
                        switch item.type {
                        case .movie:
                            let values = try await movieSources(
                                for: item,
                                provider: provider,
                                xtreamConfiguration: xtreamConfiguration
                            )
                            return (index, values)

                        case .series, .iptvSeries:
                            guard let season = item.seasonNumber,
                                  let episode = item.episodeNumber,
                                  season >= 0, episode > 0
                            else { return (index, []) }

                            let values = try await episodeSources(
                                for: item,
                                seasonNumber: season,
                                episodeNumber: episode,
                                provider: provider,
                                xtreamConfiguration: xtreamConfiguration
                            )
                            return (index, values)

                        case .liveTV:
                            return (index, [])
                        }
                    } catch {
                        // Een onbereikbare provider mag de andere resultaten
                        // niet verbergen.
                        return (index, [])
                    }
                }
            }

            var results: [(Int, [PlayableSource])] = []
            for await values in group {
                results.append(values)
            }
            return results.sorted { $0.0 < $1.0 }.flatMap(\.1)
        }
    }

    // MARK: - Movies

    private func movieSources(
        for item: MediaItem,
        provider: IPTVStoredProvider,
        xtreamConfiguration:
            XtreamConfiguration
    ) async throws -> [PlayableSource] {
        let configuration = provider.configuration

        let unfilteredCatalog:
            [IPTVVODItem]

        if let cached =
            await cache.cachedItems(
                providerIdentifier:
                    configuration
                        .providerIdentifier
            )
        {
            unfilteredCatalog = cached
        } else {
            let values =
                try await service
                    .loadXtreamVOD(
                        configuration:
                            xtreamConfiguration,
                        categoryID: nil
                    )

            try Task.checkCancellation()

            await cache.store(
                values,
                providerIdentifier:
                    configuration
                        .providerIdentifier
            )

            unfilteredCatalog = values
        }

        try Task.checkCancellation()

        // Cache de volledige catalogus; zichtbaarheid wordt bij iedere
        // zoekactie opnieuw toegepast, ook na een wijziging in Instellingen.
        let preferences = preferencesStore.load(for: configuration)
        let catalog = unfilteredCatalog.filter { vodItem in
            guard preferences.isVODItemVisible(vodItem.id) else { return false }
            guard let categoryID = vodItem.categoryID, !categoryID.isEmpty
            else { return true }
            return preferences.isVODCategoryVisible(categoryID)
        }

        let target =
            Self.normalizedTitle(
                item.title
            )

        guard !target.isEmpty else {
            return []
        }

        let targetYear =
            Self.year(
                from: item.releaseDate
            )

        var candidates:
            [(item: IPTVVODItem, score: Int)]
            = []

        for vodItem in catalog {
            try Task.checkCancellation()

            let candidate =
                Self.normalizedTitle(
                    vodItem.name
                )

            guard
                !candidate.isEmpty
            else {
                continue
            }

            let score =
                Self.matchScore(
                    target: target,
                    candidate:
                        candidate,
                    targetYear:
                        targetYear,
                    originalCandidate:
                        vodItem.name
                )

            guard score > 0 else {
                continue
            }

            candidates.append(
                (
                    item:
                        vodItem,
                    score:
                        score
                )
            )
        }

        let sorted =
            candidates.sorted {
                if $0.score != $1.score {
                    return $0.score > $1.score
                }

                return $0.item.name
                    .localizedStandardCompare(
                        $1.item.name
                    )
                    == .orderedAscending
            }

        // Alle duidelijke titelmatches tonen; alleen voor zwakke/fuzzy
        // matches een limiet gebruiken om irrelevante resultaten te weren.
        let strongMatches = sorted.filter { $0.score >= 600 }
        let matches = strongMatches.isEmpty
            ? Array(sorted.prefix(12))
            : strongMatches

        var result:
            [PlayableSource] = []

        var seenURLs =
            Set<String>()

        for candidate in matches {
            let original =
                candidate.item
                    .playableSource

            let key =
                original.url
                    .absoluteString

            guard
                seenURLs.insert(key)
                    .inserted
            else {
                continue
            }

            result.append(
                PlayableSource(
                    name:
                        "IPTV · \(candidate.item.name)",
                    description:
                        "IPTV VOD",
                    metadata:
                        original.metadata,
                    url:
                        original.url,
                    kind:
                        .iptvVOD,
                    providerName:
                        provider.displayName,
                    requiresSoftwareVideo:
                        original
                            .requiresSoftwareVideo
                )
            )
        }

        return result
    }

    // MARK: - Episodes

    private func episodeSources(
        for item: MediaItem,
        seasonNumber: Int,
        episodeNumber: Int,
        provider: IPTVStoredProvider,
        xtreamConfiguration:
            XtreamConfiguration
    ) async throws -> [PlayableSource] {
        let configuration = provider.configuration

        let unfilteredCatalog:
            [XtreamSeriesItem]

        if let cached =
            await cache.cachedSeries(
                providerIdentifier:
                    configuration
                        .providerIdentifier
            )
        {
            unfilteredCatalog = cached
        } else {
            let values =
                try await service
                    .loadXtreamSeries(
                        configuration:
                            xtreamConfiguration,
                        categoryID: nil
                    )

            try Task.checkCancellation()

            await cache.storeSeries(
                values,
                providerIdentifier:
                    configuration
                        .providerIdentifier
            )

            unfilteredCatalog = values
        }

        try Task.checkCancellation()

        let preferences = preferencesStore.load(for: configuration)
        let catalog = unfilteredCatalog.filter { series in
            guard preferences.isSeriesItemVisible(String(series.id)) else {
                return false
            }
            guard let categoryID = series.categoryID, !categoryID.isEmpty
            else { return true }
            return preferences.isSeriesCategoryVisible(categoryID)
        }

        let target =
            Self.normalizedTitle(
                item.title
            )

        guard !target.isEmpty else {
            return []
        }

        let candidates =
            catalog
                .map { series in
                    (
                        series:
                            series,
                        score:
                            Self.matchScore(
                                target:
                                    target,
                                candidate:
                                    Self.normalizedTitle(
                                        series.name
                                    ),
                                targetYear:
                                    nil,
                                originalCandidate:
                                    series.name
                            )
                    )
                }
                .filter {
                    $0.score > 0
                }
                .sorted {
                    $0.score > $1.score
                }

        let strongMatches = candidates.filter { $0.score >= 600 }
        let matches = strongMatches.isEmpty
            ? Array(candidates.prefix(4))
            : strongMatches

        guard
            !candidates.isEmpty
        else {
            return []
        }

        var result:
            [PlayableSource] = []

        var seenURLs =
            Set<String>()

        for candidate
            in matches
        {
            try Task.checkCancellation()

            let info: XtreamSeriesInfo
            do {
                info = try await service
                    .loadXtreamSeriesInfo(
                        configuration:
                            xtreamConfiguration,
                        seriesID:
                            candidate
                                .series
                                .id
                    )
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                continue
            }

            try Task.checkCancellation()

            let episodes =
                info.episodes.filter {
                    $0.seasonNumber
                        == seasonNumber
                    &&
                    $0.episodeNumber
                        == episodeNumber
                }

            for episode in episodes {
                let source =
                    service.playableSource(
                        for: episode,
                        seriesName:
                            candidate
                                .series
                                .name
                    )

                let key =
                    source.url
                        .absoluteString

                guard
                    seenURLs.insert(key)
                        .inserted
                else {
                    continue
                }

                result.append(
                    PlayableSource(
                        name: source.name,
                        description: source.description,
                        metadata: source.metadata,
                        url: source.url,
                        kind: source.kind,
                        providerName: provider.displayName,
                        requiresSoftwareVideo: source.requiresSoftwareVideo
                    )
                )
            }

        }

        return result
    }

    // MARK: - Matching

    private static func matchScore(
        target: String,
        candidate: String,
        targetYear: String?,
        originalCandidate: String
    ) -> Int {
        guard
            !target.isEmpty,
            !candidate.isEmpty
        else {
            return 0
        }

        var score = 0

        if candidate == target {
            score = 1000

        } else if candidate.hasPrefix(
            target + " "
        ) {
            score = 850

        } else if candidate.hasSuffix(
            " " + target
        ) {
            score = 800

        } else if candidate.contains(
            " " + target + " "
        ) {
            score = 750

        } else if target.hasPrefix(
            candidate + " "
        ) {
            score = 650

        } else if target.contains(
            " " + candidate + " "
        ) {
            score = 600

        } else {
            let targetWords =
                Set(
                    target.split(
                        separator: " "
                    )
                )

            let candidateWords =
                Set(
                    candidate.split(
                        separator: " "
                    )
                )

            guard
                !targetWords.isEmpty,
                !candidateWords.isEmpty
            else {
                return 0
            }

            let common =
                targetWords
                    .intersection(
                        candidateWords
                    )
                    .count

            let required =
                max(
                    1,
                    min(
                        targetWords.count,
                        candidateWords.count
                    )
                    - 1
                )

            guard common >= required else {
                return 0
            }

            score =
                400 + common * 20
        }

        if
            let targetYear,
            originalCandidate.contains(
                targetYear
            )
        {
            score += 100
        }

        return score
    }

    private static func normalizedTitle(
        _ value: String
    ) -> String {
        var result =
            value
                .folding(
                    options: [
                        .diacriticInsensitive,
                        .caseInsensitive
                    ],
                    locale:
                        Locale(
                            identifier:
                                "en_US_POSIX"
                        )
                )
                .lowercased()

        result =
            result.replacingOccurrences(
                of:
                    #"[\(\[]?(19|20)\d{2}[\)\]]?"#,
                with:
                    " ",
                options:
                    .regularExpression
            )

        let removable = [
            "4k",
            "uhd",
            "fhd",
            "2160p",
            "2160",
            "1080p",
            "1080",
            "720p",
            "720",
            "hdr10",
            "hdr",
            "dolby vision",
            "dolby",
            "atmos",
            "hevc",
            "x265",
            "x264",
            "h265",
            "h264",
            "web dl",
            "webdl",
            "blu ray",
            "bluray",
            "remux"
        ]

        for token in removable {
            result =
                result.replacingOccurrences(
                    of: token,
                    with: " "
                )
        }

        result =
            result.replacingOccurrences(
                of:
                    #"(^|\s)(nl|be|en|multi|dual|dubbed)(\s|$)"#,
                with:
                    " ",
                options:
                    .regularExpression
            )

        result =
            result.replacingOccurrences(
                of:
                    #"[^a-z0-9]+"#,
                with:
                    " ",
                options:
                    .regularExpression
            )

        result =
            result.replacingOccurrences(
                of:
                    #"\s+"#,
                with:
                    " ",
                options:
                    .regularExpression
            )

        return result
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
    }

    private static func year(
        from value: String?
    ) -> String? {
        guard
            let value
        else {
            return nil
        }

        let trimmed =
            value.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        guard
            trimmed.count >= 4
        else {
            return nil
        }

        let year =
            String(
                trimmed.prefix(4)
            )

        guard
            year.count == 4,
            year.allSatisfy(
                \.isNumber
            )
        else {
            return nil
        }

        return year
    }
}
