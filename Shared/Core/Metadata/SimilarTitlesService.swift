import Foundation

/// Films/series "van hetzelfde type/genre" als een gegeven titel, voor de
/// "Vergelijkbaar"-rij onderaan een film-/seriedetailscherm (tvOS + iOS).
/// Gebruikt TMDB's eigen `/similar`-eindpunten (film blijft bij films,
/// serie blijft bij series).
enum SimilarTitlesService {
    static func similarItems(for item: MediaItem) async -> [MediaItem] {
        guard let tmdbID = item.tmdbID else { return [] }

        switch item.type {
        case .movie:
            guard let token = AppConfiguration.tmdbReadAccessToken else { return [] }
            let client = TMDBClient(readAccessToken: token)
            guard let movies = try? await client.similarMovies(id: tmdbID) else { return [] }
            return newestFirst(movies.map(mediaItem(from:)))

        case .series:
            guard let service = SeriesService() else { return [] }
            guard let series = try? await service.similarSeries(id: tmdbID) else { return [] }
            return newestFirst(series.map(mediaItem(from:)))

        default:
            return []
        }
    }

    /// TMDB geeft datums als yyyy-MM-dd terug. De alfabetische volgorde is
    /// daardoor ook de datumvolgorde. Titels zonder datum komen achteraan;
    /// bij dezelfde datum blijft TMDB's oorspronkelijke volgorde behouden.
    private static func newestFirst(_ items: [MediaItem]) -> [MediaItem] {
        items.enumerated()
            .sorted { lhs, rhs in
                let leftDate = lhs.element.releaseDate ?? ""
                let rightDate = rhs.element.releaseDate ?? ""
                return leftDate == rightDate ? lhs.offset < rhs.offset : leftDate > rightDate
            }
            .map(\.element)
    }

    private static func mediaItem(from movie: TMDBMovie) -> MediaItem {
        MediaItem(
            title: movie.title,
            type: .movie,
            tmdbID: movie.id,
            overview: movie.overview,
            releaseDate: movie.releaseDate,
            posterURL: TMDBImageURLBuilder.poster(movie.posterPath),
            backdropURL: TMDBImageURLBuilder.backdrop(movie.backdropPath),
            genre: TMDBGenreNames.firstMovieName(for: movie.genreIDs ?? []),
            rating: movie.voteAverage
        )
    }

    private static func mediaItem(from series: TMDBSeries) -> MediaItem {
        MediaItem(
            title: series.name,
            type: .series,
            tmdbID: series.id,
            overview: series.overview,
            releaseDate: series.firstAirDate,
            posterURL: TMDBImageURLBuilder.poster(series.posterPath),
            backdropURL: TMDBImageURLBuilder.backdrop(series.backdropPath),
            genre: TMDBGenreNames.firstTVName(for: series.genreIDs ?? []),
            rating: series.voteAverage
        )
    }
}
