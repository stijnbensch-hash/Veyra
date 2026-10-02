import Foundation

struct TMDBService {
    private let client: TMDBClient

    init?() {
        guard let token = AppConfiguration.tmdbReadAccessToken else {
            return nil
        }

        client = TMDBClient(
            readAccessToken: token
        )
    }

    func mediaItem(forMovieID id: Int) async throws -> MediaItem {
        let movie = try await client.movieDetails(id: id)
        return try await mediaItem(for: movie)
    }

    /// Speelduur in minuten, voor Veyra Pulse op `MovieDetailView` -- `TMDBMovie` uit een
    /// lijst-/ontdek-eindpunt kent dit niet, dus dit haalt altijd het detail-eindpunt op.
    func runtimeMinutes(forMovieID id: Int) async throws -> Int? {
        try await client.movieDetails(id: id).runtime
    }

    /// Of deze film onderdeel is van een officiële TMDB-collectie (Fase 7, spec §33) -- nooit
    /// een hardcoded lijst, enkel wat TMDB zelf meegeeft op het filmdetail.
    func belongsToCollection(forMovieID id: Int) async throws -> TMDBBelongsToCollection? {
        try await client.movieDetails(id: id).belongsToCollection
    }
    

    func popularMovies() async throws -> [TMDBMovie] {
        try await client.popularMovies()
    }

    /// Fase 7 (Search §43: pagination). `page` 1 = eerste, snelle resultaten; hogere
    /// pagina's enkel op expliciete "meer laden" (scroll/prefetch) vanuit de view.
    func searchMovies(query: String, page: Int = 1) async throws -> TMDBMoviePage {
        try await client.searchMovies(query: query, page: page)
    }

    func mediaItem(for movie: TMDBMovie) async throws -> MediaItem {
        let externalIDs = try await client.externalIDs(
            forMovieID: movie.id
        )

        return MediaItem(
            title: movie.title,
            type: .movie,
            imdbID: externalIDs.imdbID,
            tmdbID: movie.id,
            overview: normalized(movie.overview),
            releaseDate: normalized(movie.releaseDate),
            // Fase 5 (TMDB-spec, image URL builder): gecentraliseerd i.p.v. een eigen
            // `imageBaseURL`/`imageURL(path:size:)` hier.
            posterURL: TMDBImageURLBuilder.poster(movie.posterPath),
            backdropURL: TMDBImageURLBuilder.backdrop(movie.backdropPath)
        )
    }

    private func normalized(
        _ value: String?
    ) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return trimmed.isEmpty ? nil : trimmed
    }
}
