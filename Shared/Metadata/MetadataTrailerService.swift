import Foundation

/// Haalt de YouTube-trailer op voor een film of serie via TMDB's
/// `/videos`-endpoint. Geeft `nil` terug als er geen sleutel/API-token is,
/// het verzoek faalt, of TMDB geen bruikbare video teruggeeft.
enum MetadataTrailerService {
    static func youtubeKey(forMovieTmdbID tmdbID: Int) async -> String? {
        guard let token = AppConfiguration.tmdbReadAccessToken else { return nil }
        let client = TMDBClient(readAccessToken: token)
        let videos = try? await client.videos(forMovieID: tmdbID)
        return videos?.bestTrailerKey
    }

    static func youtubeKey(forSeriesTmdbID tmdbID: Int) async -> String? {
        guard let service = SeriesService() else { return nil }
        let videos = try? await service.videos(forSeriesID: tmdbID)
        return videos?.bestTrailerKey
    }
}
