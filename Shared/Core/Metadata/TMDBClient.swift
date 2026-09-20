import Foundation

// The catalog language is independent from the selected availability country.
enum CatalogLocalization { nonisolated static let language = "nl-NL" }

struct TMDBClient {
    private let session: URLSession
    private let readAccessToken: String
    private let language: String

    init(
        readAccessToken: String,
        language: String = CatalogLocalization.language,
        session: URLSession = .shared
    ) {
        self.readAccessToken = readAccessToken
        self.language = language
        self.session = session
    }

    func movieDetails(id: Int) async throws -> TMDBMovie {
        try await request(path: "/3/movie/\(id)")
    }

    func popularMovies() async throws -> [TMDBMovie] {
        let response: TMDBMoviePage = try await request(
            path: "/3/movie/popular"
        )

        return response.results
    }

    func topRatedMovies() async throws -> [TMDBMovie] {
        let response: TMDBMoviePage = try await request(path: "/3/movie/top_rated")
        return response.results
    }

    func nowPlayingMovies() async throws -> [TMDBMovie] {
        let response: TMDBMoviePage = try await request(path: "/3/movie/now_playing")
        return response.results
    }

    func upcomingMovies() async throws -> [TMDBMovie] {
        let response: TMDBMoviePage = try await request(path: "/3/movie/upcoming")
        return response.results
    }

    func trendingMovies(window: String = "week") async throws -> [TMDBMovie] {
        let response: TMDBMoviePage = try await request(path: "/3/trending/movie/\(window)")
        return response.results
    }

    func searchMovies(query: String) async throws -> [TMDBMovie] {
        guard !query.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty else {
            return []
        }

        let response: TMDBMoviePage = try await request(
            path: "/3/search/movie",
            queryItems: [
                URLQueryItem(
                    name: "query",
                    value: query
                )
            ]
        )

        return response.results
    }

    func externalIDs(
        forMovieID movieID: Int
    ) async throws -> TMDBExternalIDs {
        try await request(
            path: "/3/movie/\(movieID)/external_ids"
        )
    }

    /// Haalt een publieke TMDB-lijst op (bv. een eigen lijst van de
    /// gebruiker) via het v4 lijst-ID. Werkt zonder gebruikersaccount zolang
    /// de lijst publiek is.
    func list(id: Int) async throws -> TMDBListDetails {
        try await request(path: "/4/list/\(id)")
    }

    func request<Response: Decodable>(
        path: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> Response {
        var components = URLComponents()

        components.scheme = "https"
        components.host = "api.themoviedb.org"
        components.path = path

        var localizedQueryItems = queryItems
        localizedQueryItems.append(
            URLQueryItem(
                name: "language",
                value: language
            )
        )

        components.queryItems = localizedQueryItems

        guard let url = components.url else {
            throw TMDBError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        request.setValue(
            "Bearer \(readAccessToken)",
            forHTTPHeaderField: "Authorization"
        )

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )

        let (data, response) = try await session.data(
            for: request
        )

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TMDBError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw TMDBError.httpError(
                statusCode: httpResponse.statusCode
            )
        }

        do {
            return try JSONDecoder().decode(
                Response.self,
                from: data
            )
        } catch {
            throw TMDBError.decodingFailed
        }
    }
}

struct TMDBMoviePage: Decodable {
    let page: Int
    let results: [TMDBMovie]
}

/// Respons van `GET /4/list/{list_id}` — een (eigen) TMDB-lijst, die films
/// en series door elkaar kan bevatten (onderscheiden via `media_type`).
struct TMDBListDetails: Decodable {
    let name: String?
    let results: [TMDBListItem]
}

struct TMDBListItem: Decodable, Hashable {
    let id: Int
    let mediaType: String?
    let title: String?
    let name: String?
    let overview: String?
    let releaseDate: String?
    let firstAirDate: String?
    let posterPath: String?
    let backdropPath: String?

    enum CodingKeys: String, CodingKey {
        case id
        case mediaType = "media_type"
        case title
        case name
        case overview
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
    }

    /// `true` voor films: expliciet via `media_type`, anders wanneer er een
    /// `title`/`release_date` (film) in plaats van `name`/`first_air_date`
    /// (serie) aanwezig is.
    var isMovie: Bool {
        if let mediaType { return mediaType == "movie" }
        return title != nil
    }

    var displayTitle: String { (isMovie ? title : name) ?? title ?? name ?? "Onbekende titel" }
    var displayReleaseDate: String? { isMovie ? releaseDate : firstAirDate }
}

struct TMDBMovie: Decodable, Identifiable, Hashable {
    let id: Int
    let title: String
    let overview: String
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let voteAverage: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case overview
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case voteAverage = "vote_average"
    }
}

struct TMDBExternalIDs: Decodable {
    let imdbID: String?

    enum CodingKeys: String, CodingKey {
        case imdbID = "imdb_id"
    }
}

enum TMDBError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Het metadata-verzoek kon niet worden aangemaakt."

        case .invalidResponse:
            return "De metadataservice gaf een ongeldig antwoord."

        case .httpError:
            return "De metadataservice kon het verzoek niet uitvoeren."

        case .decodingFailed:
            return "De metadata konden niet worden verwerkt."
        }
    }
}
