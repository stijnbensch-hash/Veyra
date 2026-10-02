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

/// Filter titels die nog niet uitgebracht zijn (toekomstige releasedatum, of
/// helemaal geen releasedatum bekend) uit de filterknoppen (Genre/Decennium/
/// Beoordeling/Sorteren) op Films en Series -- alleen al uitgebrachte titels
/// horen daar te verschijnen.
nonisolated enum TMDBReleaseFilter {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func isReleased(_ dateString: String?, now: Date = .now) -> Bool {
        guard let dateString, !dateString.isEmpty, let date = formatter.date(from: dateString) else {
            return false
        }
        return date <= now
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

    /// Fase 4 (duplicate-request cleanup/`append_to_response`): combineert het filmdetail met
    /// gerelateerde subresources (credits/videos/reviews/...) in ÉÉN TMDB-aanvraag, zodat
    /// `CastRow`/`TrailerSection`/`ReviewsSection` die niet elk apart hoeven op te vragen (spec
    /// §13: "in plaats van /movie/{id} /movie/{id}/credits /movie/{id}/videos ..."). Alleen
    /// gebruikt waar het scherm die subresources ook werkelijk meteen nodig heeft (spec §14).
    func movieDetails(id: Int, append: [String]) async throws -> TMDBMovie {
        guard !append.isEmpty else { return try await movieDetails(id: id) }
        return try await request(
            path: "/3/movie/\(id)",
            queryItems: [URLQueryItem(name: "append_to_response", value: append.joined(separator: ","))]
        )
    }

    /// Alle delen van een officiële TMDB-collectie (spec §33/§34, Fase 7) -- bv. "Alien
    /// Collection". Wordt gevonden via `TMDBMovie.belongsToCollection` op een filmdetail, nooit
    /// via een hardcoded lijst. Fase 8 (Collections §45): lang gecached -- collectiedetails/parts
    /// wijzigen zelden, dus niet iedere keer dat een Collection-detail geopend wordt opnieuw ophalen.
    func collectionDetails(id: Int) async throws -> TMDBCollectionDetail {
        try await request(
            path: "/3/collection/\(id)",
            cacheKey: "collection:\(id):\(language)",
            cacheTTL: TMDBSearchCache.longTTL
        )
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

    /// Fase 7 (Search §43: pagination, §42: cache). `page` oplopend bij "meer laden"
    /// (scroll/prefetch), nooit vooraf meerdere pagina's tegelijk ophalen.
    func searchMovies(query: String, page: Int = 1) async throws -> TMDBMoviePage {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return TMDBMoviePage(page: page, results: [], totalPages: 0)
        }

        return try await request(
            path: "/3/search/movie",
            queryItems: [
                URLQueryItem(name: "query", value: trimmed),
                URLQueryItem(name: "page", value: String(page))
            ],
            cacheKey: "search:movie:\(trimmed.lowercased()):\(page):\(language)"
        )
    }

    func externalIDs(
        forMovieID movieID: Int
    ) async throws -> TMDBExternalIDs {
        try await request(
            path: "/3/movie/\(movieID)/external_ids"
        )
    }

    /// De trailers/teasers van TMDB zelf (meestal YouTube-video's).
    func videos(forMovieID movieID: Int) async throws -> [TMDBVideo] {
        let response: TMDBVideosResponse = try await request(
            path: "/3/movie/\(movieID)/videos"
        )
        return response.results
    }

    /// Door kijkers geschreven recensies (Engelstalig -- TMDB vertaalt deze
    /// niet), voor de recensiesectie op het filmdetailscherm.
    func reviews(forMovieID movieID: Int) async throws -> [TMDBReview] {
        let response: TMDBReviewsResponse = try await request(
            path: "/3/movie/\(movieID)/reviews"
        )
        return response.results
    }

    /// Films "van hetzelfde type/genre" als de opgegeven film, voor de
    /// "Vergelijkbaar"-rij onderaan het filmdetailscherm.
    func similarMovies(id: Int) async throws -> [TMDBMovie] {
        let response: TMDBMoviePage = try await request(path: "/3/movie/\(id)/similar")
        return response.results.filter { TMDBCatalogLanguageFilter.allows($0.originalLanguage) }
    }

    /// Haalt een publieke TMDB-lijst op (bv. een eigen lijst van de
    /// gebruiker) via het v4 lijst-ID. Werkt zonder gebruikersaccount zolang
    /// de lijst publiek is.
    func list(id: Int) async throws -> TMDBListDetails {
        try await request(path: "/4/list/\(id)")
    }

    func request<Response: Decodable>(
        path: String,
        queryItems: [URLQueryItem] = [],
        cacheKey: String? = nil,
        cacheTTL: TimeInterval = TMDBSearchCache.defaultTTL
    ) async throws -> Response {
        if let cacheKey, let cached = await TMDBSearchCache.shared.data(for: cacheKey),
           let decoded = try? JSONDecoder().decode(Response.self, from: cached) {
            return decoded
        }

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

        // Fase 2 (Request Foundation): gedeelde single-flight/retry/429-afhandeling i.p.v.
        // een losse `session.data(for:)` per client -- zie `TMDBRequestCoordinator`.
        let data: Data
        do {
            data = try await TMDBRequestCoordinator.shared.data(for: request, key: url.absoluteString)
        } catch let error as TMDBCoordinatorError {
            switch error {
            case .httpError(let statusCode):
                throw TMDBError.httpError(statusCode: statusCode)
            case .rateLimited:
                throw TMDBError.httpError(statusCode: 429)
            case .invalidResponse:
                throw TMDBError.invalidResponse
            }
        }

        do {
            let decoded = try JSONDecoder().decode(
                Response.self,
                from: data
            )
            if let cacheKey {
                await TMDBSearchCache.shared.store(data, for: cacheKey, ttl: cacheTTL)
            }
            return decoded
        } catch {
            throw TMDBError.decodingFailed
        }
    }
}

struct TMDBMoviePage: Decodable {
    let page: Int
    let results: [TMDBMovie]
    let totalPages: Int

    enum CodingKeys: String, CodingKey {
        case page
        case results
        case totalPages = "total_pages"
    }
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
    /// Alleen aanwezig op TMDB's detail-eindpunt (`movieDetails(id:)`) -- de
    /// tegenhanger van `genreIDs` daar, met de naam al ingevuld (in plaats van
    /// enkel een id die eerst via `TMDBGenreNames` opgezocht moet worden).
    /// Gebruikt om de genre-badge ook te vullen voor bronnen die zelf geen
    /// genre meeleveren (bv. de Trakt-watchlist, zie `ShelfCatalogService.enrich`).
    var genres: [TMDBGenreEntry]? = nil
    /// Alleen aanwezig op TMDB's detail-eindpunt (`movieDetails(id:)`), niet op
    /// lijst-/ontdek-eindpunten -- gebruikt voor de speelduur in Veyra Pulse
    /// op `MovieDetailView` (zie `TMDBService.runtimeMinutes(forMovieID:)`).
    var runtime: Int? = nil
    /// Alleen aanwezig op TMDB's detail-eindpunt -- welke officiële TMDB-collectie (bv. "Alien
    /// Collection") deze film bevat, indien van toepassing. Basis voor Fase 7 (spec §33).
    var belongsToCollection: TMDBBelongsToCollection? = nil
    /// Alleen aanwezig als `movieDetails(id:append:)` dit opvroeg (Fase 4) -- anders `nil`,
    /// en haalt de aanroepende component (CastRow e.d.) het zelf op zoals voorheen.
    var credits: TMDBCredits? = nil
    var videos: TMDBVideosResponse? = nil
    var reviews: TMDBReviewsResponse? = nil

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
        case genres
        case runtime
        case belongsToCollection = "belongs_to_collection"
        case credits
        case videos
        case reviews
    }
}

/// `belongs_to_collection` op een TMDB-filmdetail -- enkel id/naam nodig om door te verwijzen
/// naar `TMDBClient.collectionDetails(id:)`.
struct TMDBBelongsToCollection: Decodable, Hashable {
    let id: Int
    let name: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
    }
}

/// Respons van `GET /3/collection/{id}` -- een officiële TMDB-filmreeks (spec §33/§34).
struct TMDBCollectionDetail: Decodable {
    let id: Int
    let name: String
    let overview: String?
    let parts: [TMDBCollectionPart]
}

struct TMDBCollectionPart: Decodable, Hashable {
    let id: Int
    let title: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case overview
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
    }
}

/// Eén genre zoals TMDB's detail-eindpunten die meegeven (`{"id":..,"name":..}`) --
/// i.t.t. `genreIDs` (enkel op lijst-eindpunten) is de naam hier al vertaald naar
/// de opgevraagde taal, dus geen aparte opzoektabel nodig.
struct TMDBGenreEntry: Decodable, Hashable {
    let id: Int
    let name: String
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
