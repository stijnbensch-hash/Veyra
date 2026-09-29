import Foundation

/// Haalt door kijkers geschreven recensies op via TMDB. Reviews zijn bij
/// TMDB altijd Engelstalig (geen vertaling per taalinstelling), dus hier --
/// anders dan bij `MetadataTrailerService` -- geen taalvolgorde nodig.
enum MetadataReviewsService {
    static func reviews(for item: MediaItem) async -> [TMDBReview] {
        guard let tmdbID = item.tmdbID else { return [] }
        switch item.type {
        case .movie:
            return await movieReviews(tmdbID: tmdbID)
        case .series:
            return await seriesReviews(tmdbID: tmdbID)
        case .liveTV, .iptvSeries:
            return []
        }
    }

    private static func movieReviews(tmdbID: Int) async -> [TMDBReview] {
        guard let token = AppConfiguration.tmdbReadAccessToken else { return [] }
        let client = TMDBClient(readAccessToken: token)
        return (try? await client.reviews(forMovieID: tmdbID))?.withUsableContent ?? []
    }

    private static func seriesReviews(tmdbID: Int) async -> [TMDBReview] {
        guard let service = SeriesService() else { return [] }
        return (try? await service.reviews(forSeriesID: tmdbID))?.withUsableContent ?? []
    }
}

private extension Array where Element == TMDBReview {
    /// Een enkele lege of kapotte review (voorkomt in TMDB's data) mag de
    /// hele sectie niet leeg laten lijken bij een verder prima resultaat.
    var withUsableContent: [TMDBReview] {
        filter { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}
