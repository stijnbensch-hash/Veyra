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
            return movies.map(mediaItem(from:))

        case .series:
            guard let service = SeriesService() else { return [] }
            guard let series = try? await service.similarSeries(id: tmdbID) else { return [] }
            return series.map(mediaItem(from:))

        default:
            return []
        }
    }

    private static func mediaItem(from movie: TMDBMovie) -> MediaItem {
        MediaItem(
            title: movie.title,
            type: .movie,
            tmdbID: movie.id,
            overview: movie.overview,
            releaseDate: movie.releaseDate,
            posterURL: imageURL(movie.posterPath),
            backdropURL: imageURL(movie.backdropPath, size: "w1280"),
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
            posterURL: imageURL(series.posterPath),
            backdropURL: imageURL(series.backdropPath, size: "w1280"),
            genre: TMDBGenreNames.firstTVName(for: series.genreIDs ?? []),
            rating: series.voteAverage
        )
    }

    private static func imageURL(_ path: String?, size: String = "w500") -> URL? {
        guard let path, !path.isEmpty else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/\(size)\(path)")
    }
}
