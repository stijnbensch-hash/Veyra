import Foundation

/// Haalt een bruikbare YouTube-trailer op via TMDB. Probeert eerst de
/// ingestelde Nederlandse metadatataal, daarna Engels.
enum MetadataTrailerService {
    static func trailer(for item: MediaItem) async -> TMDBVideo? {
        guard let tmdbID = item.tmdbID else { return nil }
        switch item.type {
        case .movie:
            return await movieTrailer(tmdbID: tmdbID)
        case .series:
            return await seriesTrailer(tmdbID: tmdbID)
        case .liveTV, .iptvSeries:
            return nil
        }
    }

    private static func movieTrailer(tmdbID: Int) async -> TMDBVideo? {
        guard let token = AppConfiguration.tmdbReadAccessToken else { return nil }
        for language in [CatalogLocalization.language, "en-US"] {
            let client = TMDBClient(readAccessToken: token, language: language)
            if let trailer = (try? await client.videos(forMovieID: tmdbID))?.bestTrailer {
                return trailer
            }
        }
        return nil
    }

    private static func seriesTrailer(tmdbID: Int) async -> TMDBVideo? {
        for language in [CatalogLocalization.language, "en-US"] {
            guard let service = SeriesService(language: language) else { return nil }
            if let trailer = (try? await service.videos(forSeriesID: tmdbID))?.bestTrailer {
                return trailer
            }
        }
        return nil
    }
}
