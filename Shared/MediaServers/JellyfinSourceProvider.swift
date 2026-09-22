import Foundation

/// Resolves streams from a connected Jellyfin server for a
/// TMDB-matched movie or episode, by title (and year, for movies).
///
/// PlaybackInfo can expose multiple MediaSources. Each playable
/// MediaSource is returned as its own ResolvedSource so the existing
/// SourceSelectionView can show them next to addons and IPTV.
struct JellyfinSourceProvider:
    ResolvedMediaSourceProvider
{
    let account: MediaServerAccount

    var name: String {
        account.name
    }

    private var service:
        JellyfinService
    {
        JellyfinService(
            account: account
        )
    }

    func sources(
        for item: MediaItem
    ) async throws -> [PlayableSource] {
        try await resolvedSources(
            for: item
        )
        .map(\.source)
    }

    func resolvedSources(
        for item: MediaItem
    ) async throws -> [ResolvedSource] {
        switch item.type {
        case .movie:
            return try await movieSources(
                for: item
            )

        case .series:
            return try await episodeSources(
                for: item
            )

        case .liveTV:
            return []
        }
    }

    // MARK: - Movies

    private func movieSources(
        for item: MediaItem
    ) async throws -> [ResolvedSource] {
        let candidates =
            try await service.search(
                term: item.title,
                includeItemTypes: [
                    "Movie"
                ]
            )

        guard
            let match =
                Self.bestMatch(
                    title: item.title,
                    year:
                        Self.year(
                            from:
                                item.releaseDate
                        ),
                    candidates:
                        candidates
                )
        else {
            return []
        }

        return try await playableResults(
            for: match
        )
    }

    // MARK: - Episodes

    private func episodeSources(
        for item: MediaItem
    ) async throws -> [ResolvedSource] {
        guard
            let seasonNumber =
                item.seasonNumber,
            let episodeNumber =
                item.episodeNumber
        else {
            return []
        }

        let seriesCandidates =
            try await service.search(
                term: item.title,
                includeItemTypes: [
                    "Series"
                ]
            )

        guard
            let series =
                Self.bestMatch(
                    title: item.title,
                    year: nil,
                    candidates:
                        seriesCandidates
                )
        else {
            return []
        }

        let episodes =
            try await service.episodes(
                seriesID: series.id
            )

        guard
            let episode =
                episodes.first(
                    where: {
                        $0.parentIndexNumber
                            == seasonNumber
                            && $0.indexNumber
                                == episodeNumber
                    }
                )
        else {
            return []
        }

        return try await playableResults(
            for: episode
        )
    }

    // MARK: - Building results

    private func playableResults(
        for jellyfinItem: JellyfinItem
    ) async throws -> [ResolvedSource] {
        let playbackInfo =
            try await service.playbackInfo(
                for: jellyfinItem
            )

        var results:
            [ResolvedSource] = []

        for mediaSource
            in playbackInfo.mediaSources
        {
            guard
                let url =
                    service.playbackURL(
                        for:
                            jellyfinItem,
                        mediaSource:
                            mediaSource
                    )
            else {
                continue
            }

            let sourceName =
                mediaSource.name?
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )

            let displayName:
                String

            if
                let sourceName,
                !sourceName.isEmpty
            {
                displayName =
                    sourceName
            } else {
                displayName =
                    "\(account.name) · \(jellyfinItem.displayTitle)"
            }

            let description =
                sourceDescription(
                    mediaSource:
                        mediaSource,
                    jellyfinItem:
                        jellyfinItem
                )

            let source =
                PlayableSource(
                    name:
                        displayName,
                    description:
                        description,
                    url:
                        url,
                    kind:
                        .direct,
                    providerName:
                        account.name
                )

            results.append(
                ResolvedSource(
                    source:
                        source,
                    originName:
                        account.name
                )
            )
        }

        return results
    }

    private func sourceDescription(
        mediaSource: JellyfinMediaSource,
        jellyfinItem: JellyfinItem
    ) -> String? {
        var parts:
            [String] = []

        if
            let container =
                mediaSource.container?
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    ),
            !container.isEmpty
        {
            parts.append(
                container.uppercased()
            )
        }

        if
            let size =
                mediaSource.size,
            size > 0
        {
            parts.append(
                ByteCountFormatter
                    .string(
                        fromByteCount:
                            size,
                        countStyle:
                            .file
                    )
            )
        }

        if
            let bitrate =
                mediaSource.bitrate,
            bitrate > 0
        {
            let megabits =
                Double(bitrate)
                    / 1_000_000

            parts.append(
                String(
                    format:
                        "%.1f Mbps",
                    megabits
                )
            )
        }

        if !parts.isEmpty {
            return parts.joined(
                separator: " · "
            )
        }

        return jellyfinItem.overview
    }

    // MARK: - Matching

    private static func bestMatch(
        title: String,
        year: Int?,
        candidates: [JellyfinItem]
    ) -> JellyfinItem? {
        let normalizedTitle =
            normalize(title)

        let titleMatches =
            candidates.filter {
                normalize($0.name)
                    == normalizedTitle
            }

        guard
            !titleMatches.isEmpty
        else {
            return nil
        }

        guard
            let year
        else {
            return titleMatches.first
        }

        return titleMatches.first {
            $0.productionYear == year
        }
            ?? titleMatches.first
    }

    private static func normalize(
        _ value: String
    ) -> String {
        value
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
            .lowercased()
    }

    private static func year(
        from releaseDate: String?
    ) -> Int? {
        guard
            let releaseDate,
            releaseDate.count >= 4
        else {
            return nil
        }

        return Int(
            releaseDate.prefix(4)
        )
    }
}
