import Foundation

/// Bepaalt de eerstvolgende aflevering na een gegeven `MediaItem`, puur op
/// basis van TMDB-seizoen/aflevering-nummers — onafhankelijk van Trakt, zodat
/// de "Volgende aflevering"-knop in de player altijd werkt, ook zonder
/// Trakt-koppeling.
enum NextEpisodeResolver {
    static func resolve(after item: MediaItem?) async -> MediaItem? {
        guard let item, item.type == .series,
              let seriesID = item.tmdbID,
              let seasonNumber = item.seasonNumber,
              let episodeNumber = item.episodeNumber,
              let imdbID = item.imdbID, !imdbID.isEmpty,
              let service = SeriesService()
        else { return nil }

        do {
            let currentSeason = try await service.season(seriesID: seriesID, seasonNumber: seasonNumber)

            if let next = currentSeason.episodes.first(where: { $0.episodeNumber == episodeNumber + 1 }) {
                return mediaItem(
                    seriesID: seriesID, imdbID: imdbID, seriesTitle: item.title,
                    backdropURL: item.backdropURL, episode: next
                )
            }

            let details = try await service.seriesDetails(id: seriesID)
            let nextSeasonNumber = seasonNumber + 1

            guard details.seasons.contains(where: { $0.seasonNumber == nextSeasonNumber }) else {
                return nil
            }

            let nextSeason = try await service.season(seriesID: seriesID, seasonNumber: nextSeasonNumber)

            guard let firstEpisode = nextSeason.episodes.sorted(by: { $0.episodeNumber < $1.episodeNumber }).first
            else { return nil }

            return mediaItem(
                seriesID: seriesID, imdbID: imdbID, seriesTitle: item.title,
                backdropURL: item.backdropURL, episode: firstEpisode
            )
        } catch {
            return nil
        }
    }

    private static func mediaItem(
        seriesID: Int, imdbID: String, seriesTitle: String, backdropURL: URL?, episode: TMDBEpisode
    ) -> MediaItem {
        MediaItem(
            // Voor seriebronnen moet dit de serietitel zijn, niet de afleveringstitel.
            title: seriesTitle,
            type: .series,
            imdbID: imdbID,
            tmdbID: seriesID,
            episodeTMDBID: episode.id,
            seasonNumber: episode.seasonNumber,
            episodeNumber: episode.episodeNumber,
            overview: episode.overview,
            releaseDate: episode.airDate,
            posterURL: imageURL(path: episode.stillPath),
            backdropURL: backdropURL
        )
    }

    private static func imageURL(path: String?, size: String = "w500") -> URL? {
        guard let path, !path.isEmpty else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/\(size)\(path)")
    }
}
