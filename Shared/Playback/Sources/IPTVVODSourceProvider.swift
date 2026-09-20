import Foundation

actor IPTVVODCatalogCache {
    static let shared =
        IPTVVODCatalogCache()

    private struct MovieEntry {
        let providerIdentifier: String
        let loadedAt: Date
        let items: [IPTVVODItem]
    }

    private struct SeriesEntry {
        let providerIdentifier: String
        let loadedAt: Date
        let items: [XtreamSeriesItem]
    }

    private var movieEntry:
        MovieEntry?

    private var seriesEntry:
        SeriesEntry?

    private let lifetime:
        TimeInterval = 15 * 60

    func cachedItems(
        providerIdentifier: String
    ) -> [IPTVVODItem]? {
        guard
            let movieEntry,
            movieEntry.providerIdentifier
                == providerIdentifier,
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
        movieEntry =
            MovieEntry(
                providerIdentifier:
                    providerIdentifier,
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
            let seriesEntry,
            seriesEntry.providerIdentifier
                == providerIdentifier,
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
        seriesEntry =
            SeriesEntry(
                providerIdentifier:
                    providerIdentifier,
                loadedAt:
                    Date(),
                items:
                    items
            )
    }

    func invalidate() {
        movieEntry = nil
        seriesEntry = nil
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

        guard
            let configuration =
                try configurationStore.load()
        else {
            return []
        }

        guard
            case .xtream(
                let xtreamConfiguration
            ) = configuration
        else {
            return []
        }

        switch item.type {
        case .movie:
            return try await movieSources(
                for: item,
                configuration:
                    configuration,
                xtreamConfiguration:
                    xtreamConfiguration
            )

        default:
            guard
                let seasonNumber =
                    item.seasonNumber,
                let episodeNumber =
                    item.episodeNumber,
                seasonNumber >= 0,
                episodeNumber > 0
            else {
                return []
            }

            return try await episodeSources(
                for: item,
                seasonNumber:
                    seasonNumber,
                episodeNumber:
                    episodeNumber,
                configuration:
                    configuration,
                xtreamConfiguration:
                    xtreamConfiguration
            )
        }
    }

    // MARK: - Movies

    private func movieSources(
        for item: MediaItem,
        configuration:
            IPTVStoredConfiguration,
        xtreamConfiguration:
            XtreamConfiguration
    ) async throws -> [PlayableSource] {
        let preferences =
            preferencesStore.load(
                for: configuration
            )

        let catalog:
            [IPTVVODItem]

        if let cached =
            await cache.cachedItems(
                providerIdentifier:
                    configuration
                        .providerIdentifier
            )
        {
            catalog = cached
        } else {
            let values =
                try await service
                    .loadXtreamVOD(
                        configuration:
                            xtreamConfiguration,
                        categoryID: nil
                    )

            try Task.checkCancellation()

            let filtered =
                values.filter { vodItem in
                    guard
                        preferences
                            .isVODItemVisible(
                                vodItem.id
                            )
                    else {
                        return false
                    }

                    guard
                        let categoryID =
                            vodItem.categoryID,
                        !categoryID.isEmpty
                    else {
                        return true
                    }

                    return preferences
                        .isVODCategoryVisible(
                            categoryID
                        )
                }

            await cache.store(
                filtered,
                providerIdentifier:
                    configuration
                        .providerIdentifier
            )

            catalog = filtered
        }

        try Task.checkCancellation()

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

        var result:
            [PlayableSource] = []

        var seenURLs =
            Set<String>()

        for candidate in sorted.prefix(12) {
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
        configuration:
            IPTVStoredConfiguration,
        xtreamConfiguration:
            XtreamConfiguration
    ) async throws -> [PlayableSource] {
        let preferences =
            preferencesStore.load(
                for: configuration
            )

        let catalog:
            [XtreamSeriesItem]

        if let cached =
            await cache.cachedSeries(
                providerIdentifier:
                    configuration
                        .providerIdentifier
            )
        {
            catalog = cached
        } else {
            let values =
                try await service
                    .loadXtreamSeries(
                        configuration:
                            xtreamConfiguration,
                        categoryID: nil
                    )

            try Task.checkCancellation()

            let filtered =
                values.filter { series in
                    guard
                        let categoryID =
                            series.categoryID,
                        !categoryID.isEmpty
                    else {
                        return true
                    }

                    return preferences
                        .isVODCategoryVisible(
                            categoryID
                        )
                }

            await cache.storeSeries(
                filtered,
                providerIdentifier:
                    configuration
                        .providerIdentifier
            )

            catalog = filtered
        }

        try Task.checkCancellation()

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
            in candidates.prefix(4)
        {
            try Task.checkCancellation()

            let info =
                try await service
                    .loadXtreamSeriesInfo(
                        configuration:
                            xtreamConfiguration,
                        seriesID:
                            candidate
                                .series
                                .id
                    )

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

                result.append(source)
            }

            if !result.isEmpty {
                break
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
