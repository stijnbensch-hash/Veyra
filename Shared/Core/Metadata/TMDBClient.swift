import Foundation

// The catalog language is independent from the selected availability country.
enum CatalogLocalization { nonisolated static let language = "nl-NL" }

/// Filter only automatic TMDB catalog lists. Search, details and personal lists
/// remain available regardless of the original language of a title.
nonisolated enum TMDBCatalogLanguageFilter {
    static let key = "catalog.originalLanguages"
    static var selected: String { UserDefaults.standard.string(forKey: key) ?? "nl-en" }

    static func allows(_ language: String?) -> Bool {
        guard selected != "all" else { return true }
        guard let language, !language.isEmpty else { return true }
        return language == "nl" || language == "en"
    }
}

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
        try await catalogMovies(path: "/3/movie/popular")
    }

    func topRatedMovies() async throws -> [TMDBMovie] {
        try await catalogMovies(path: "/3/movie/top_rated")
    }

    func nowPlayingMovies() async throws -> [TMDBMovie] {
        try await catalogMovies(path: "/3/movie/now_playing")
    }

    func upcomingMovies() async throws -> [TMDBMovie] {
        try await catalogMovies(path: "/3/movie/upcoming")
    }

    func trendingMovies(window: String = "week") async throws -> [TMDBMovie] {
        try await catalogMovies(path: "/3/trending/movie/\(window)")
    }

    private func catalogMovies(path: String) async throws -> [TMDBMovie] {
        var titles: [TMDBMovie] = []
        for page in 1...5 {
            let response: TMDBMoviePage = try await request(
                path: path, queryItems: [.init(name: "page", value: String(page))]
            )
            titles.append(contentsOf: response.results.filter { TMDBCatalogLanguageFilter.allows($0.originalLanguage) })
            if titles.count >= 20 || response.results.count < 20 { break }
        }
        return Array(titles.prefix(20))
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
    var originalLanguage: String? = nil
    /// Alleen aanwezig op lijst-/ontdek-eindpunten (bv. "populair"); TMDB's
    /// detail-eindpunt geeft in plaats daarvan volledige `genres`-objecten.
    /// Gebruikt voor de genre-badge op de poster (zie Shared/Theme/PosterEnrichmentSettings.swift).
    let genreIDs: [Int]?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case overview
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case voteAverage = "vote_average"
        case originalLanguage = "original_language"
        case genreIDs = "genre_ids"
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
