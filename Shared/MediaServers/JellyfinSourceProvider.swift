import Foundation

/// Resolves a direct stream from a connected Jellyfin server for a
/// TMDB-matched movie or episode, by title (and year, for movies).
///
/// This lets Jellyfin streams show up in SourceSelectionView next to
/// addons and IPTV, without any extra step from the user once a
/// server is connected in Instellingen > Mediaservers.
struct JellyfinSourceProvider:
    ResolvedMediaSourceProvider
{
    let account: MediaServerAccount

    var name: String { account.name }

    private var service: JellyfinService {
        JellyfinService(account: account)
    }

    func sources(
        for item: MediaItem
    ) async throws -> [PlayableSource] {
        try await resolvedSources(for: item)
            .map(\.source)
    }

    func resolvedSources(
        for item: MediaItem
    ) async throws -> [ResolvedSource] {
        switch item.type {
        case .movie:
            return try await movieSources(for: item)

        case .series:
            return try await episodeSources(for: item)

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
                includeItemTypes: ["Movie"]
            )

        guard
            let match = Self.bestMatch(
                title: item.title,
                year: Self.year(from: item.releaseDate),
                candidates: candidates
            )
        else {
            return []
        }

        return playableResult(for: match)
    }

    // MARK: - Episodes

    private func episodeSources(
        for item: MediaItem
    ) async throws -> [ResolvedSource] {
        guard
            let seasonNumber = item.seasonNumber,
            let episodeNumber = item.episodeNumber
        else {
            return []
        }

        let seriesCandidates =
            try await service.search(
                term: item.title,
                includeItemTypes: ["Series"]
            )

        guard
            let series = Self.bestMatch(
                title: item.title,
                year: nil,
                candidates: seriesCandidates
            )
        else {
            return []
        }

        let episodes =
            try await service.episodes(seriesID: series.id)

        guard
            let episode = episodes.first(where: {
                $0.parentIndexNumber == seasonNumber
                    && $0.indexNumber == episodeNumber
            })
        else {
            return []
        }

        return playableResult(for: episode)
    }

    // MARK: - Building the result

    private func playableResult(
        for jellyfinItem: JellyfinItem
    ) -> [ResolvedSource] {
        guard
            let url = service.streamURL(for: jellyfinItem)
        else {
            return []
        }

        let source = PlayableSource(
            name: "\(account.name) · \(jellyfinItem.displayTitle)",
            description: jellyfinItem.overview,
            url: url,
            kind: .direct,
            providerName: account.name
        )

        return [
            ResolvedSource(
                source: source,
                originName: account.name
            )
        ]
    }

    // MARK: - Matching

    private static func bestMatch(
        title: String,
        year: Int?,
        candidates: [JellyfinItem]
    ) -> JellyfinItem? {
        let normalizedTitle = normalize(title)

        let titleMatches = candidates.filter {
            normalize($0.name) == normalizedTitle
        }

        guard !titleMatches.isEmpty else {
            return nil
        }

        guard let year else {
            return titleMatches.first
        }

        return titleMatches.first {
            $0.productionYear == year
        } ?? titleMatches.first
    }

    private static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func year(from releaseDate: String?) -> Int? {
        guard
            let releaseDate,
            releaseDate.count >= 4
        else {
            return nil
        }

        return Int(releaseDate.prefix(4))
    }
}
