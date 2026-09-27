import Foundation

/// Haalt de ratings op die op een film- of seriepagina getoond worden,
/// voor de bronnen die de gebruiker heeft ingeschakeld in
/// Instellingen → Metadata:
/// - TMDB komt rechtstreeks van TMDB zelf (geen extra sleutel nodig).
/// - IMDb, Tomatometer en Metacritic komen van OMDb (vereist een gratis
///   API-sleutel van omdbapi.com, in te stellen via Account of Secrets.xcconfig).
/// - Trakt komt van Trakt's publieke ratings-endpoint (geen aanmelding nodig,
///   enkel de al aanwezige Trakt Client ID/Secret).
/// - MyAnimeList komt van Jikan (api.jikan.moe), een gratis, sleutelloze
///   publieke API voor MyAnimeList-data. Er wordt op titel gezocht (Jikan
///   heeft geen TMDB/IMDb-kruisverwijzing) en enkel een EXACTE
///   titelovereenkomst (na normalisatie) wordt gebruikt -- een fuzzy match
///   zou voor een niet-anime titel een willekeurige, onterechte score tonen.
///   Voor de meeste titels (geen anime) levert dit dus terecht niets op.
/// - Popcornmeter (de publieksscore van Rotten Tomatoes) en Letterboxd
///   hebben geen publiek toegankelijke API en blijven daarom altijd leeg
///   (zie de uitgeschakelde toggles in Instellingen → Metadata).
enum MetadataRatingsService {
    // MARK: - Public

    static func movieRatings(tmdbID: Int, imdbID: String?, title: String, knownTMDBRating: Double? = nil) async -> MetadataRatings {
        // Net als bij series: als er geen imdbID is meegegeven (bv. een
        // `MediaItem` dat niet via een volledige TMDB-filmdetails-call is
        // opgebouwd), eerst via TMDB proberen te achterhalen -- anders slaan
        // IMDb/Tomatometer/Metacritic (samen één OMDb-call) altijd stil over.
        let resolvedImdbID: String?
        if let imdbID, !imdbID.isEmpty {
            resolvedImdbID = imdbID
        } else if AppConfiguration.omdbAPIKey?.isEmpty == false,
                  MetadataPreferences.showIMDb || MetadataPreferences.showTomatometer
                    || MetadataPreferences.showMetacritic {
            resolvedImdbID = await resolveMovieImdbID(tmdbID: tmdbID)
        } else {
            resolvedImdbID = nil
        }

        let tmdbValue: Double?
        if MetadataPreferences.showTMDB, let knownTMDBRating, knownTMDBRating > 0 {
            tmdbValue = knownTMDBRating
        } else {
            tmdbValue = await fetchTMDBMovieRating(tmdbID: tmdbID)
        }
        let omdbValue = await fetchOMDb(imdbID: resolvedImdbID)
        let traktID = (resolvedImdbID?.isEmpty == false) ? resolvedImdbID! : String(tmdbID)
        let traktValue = await fetchTraktRating(id: traktID, kind: "movies")
        let malValue = await fetchMALRating(title: title)

        return MetadataRatings(
            imdb: omdbValue?.imdb,
            tmdb: tmdbValue,
            tomatometer: omdbValue?.tomatometer,
            metacritic: omdbValue?.metacritic,
            trakt: traktValue,
            popcornmeter: nil,
            letterboxd: nil,
            mal: malValue
        )
    }

    static func seriesRatings(tmdbID: Int, imdbID: String?, title: String, knownTMDBRating: Double? = nil) async -> MetadataRatings {
        let resolvedImdbID: String?
        if let imdbID, !imdbID.isEmpty {
            resolvedImdbID = imdbID
        } else if AppConfiguration.omdbAPIKey?.isEmpty == false,
                  MetadataPreferences.showIMDb || MetadataPreferences.showTomatometer
                    || MetadataPreferences.showMetacritic {
            resolvedImdbID = await resolveSeriesImdbID(tmdbID: tmdbID)
        } else {
            resolvedImdbID = nil
        }

        let tmdbValue: Double?
        if MetadataPreferences.showTMDB, let knownTMDBRating, knownTMDBRating > 0 {
            tmdbValue = knownTMDBRating
        } else {
            tmdbValue = await fetchTMDBSeriesRating(tmdbID: tmdbID)
        }
        let omdbValue = await fetchOMDb(imdbID: resolvedImdbID)
        let traktID = (resolvedImdbID?.isEmpty == false) ? resolvedImdbID! : String(tmdbID)
        let traktValue = await fetchTraktRating(id: traktID, kind: "shows")
        let malValue = await fetchMALRating(title: title)

        return MetadataRatings(
            imdb: omdbValue?.imdb,
            tmdb: tmdbValue,
            tomatometer: omdbValue?.tomatometer,
            metacritic: omdbValue?.metacritic,
            trakt: traktValue,
            popcornmeter: nil,
            letterboxd: nil,
            mal: malValue
        )
    }

    // MARK: - TMDB

    private static func fetchTMDBMovieRating(tmdbID: Int) async -> Double? {
        guard MetadataPreferences.showTMDB,
              let token = AppConfiguration.tmdbReadAccessToken
        else { return nil }

        let client = TMDBClient(readAccessToken: token)
        return try? await client.movieDetails(id: tmdbID).voteAverage
    }

    private static func fetchTMDBSeriesRating(tmdbID: Int) async -> Double? {
        guard MetadataPreferences.showTMDB, let service = SeriesService() else { return nil }
        return try? await service.seriesDetails(id: tmdbID).voteAverage
    }

    private static func resolveSeriesImdbID(tmdbID: Int) async -> String? {
        guard let service = SeriesService() else { return nil }
        return try? await service.externalIDs(forSeriesID: tmdbID).imdbID
    }

    private static func resolveMovieImdbID(tmdbID: Int) async -> String? {
        guard let token = AppConfiguration.tmdbReadAccessToken else { return nil }
        let client = TMDBClient(readAccessToken: token)
        return try? await client.externalIDs(forMovieID: tmdbID).imdbID
    }

    // MARK: - OMDb (IMDb / Tomatometer / Metacritic)

    private struct OMDbResponse: Decodable {
        var imdbRating: String?
        var ratings: [OMDbRating]?

        enum CodingKeys: String, CodingKey {
            case imdbRating
            case ratings = "Ratings"
        }
    }

    private struct OMDbRating: Decodable {
        var source: String
        var value: String

        enum CodingKeys: String, CodingKey {
            case source = "Source"
            case value = "Value"
        }
    }

    private static func fetchOMDb(
        imdbID: String?
    ) async -> (imdb: Double?, tomatometer: Int?, metacritic: Int?)? {
        guard let imdbID, !imdbID.isEmpty,
              let apiKey = AppConfiguration.omdbAPIKey, !apiKey.isEmpty,
              MetadataPreferences.showIMDb || MetadataPreferences.showTomatometer
                || MetadataPreferences.showMetacritic
        else { return nil }

        var components = URLComponents(string: "https://www.omdbapi.com/")
        components?.queryItems = [
            URLQueryItem(name: "i", value: imdbID),
            URLQueryItem(name: "apikey", value: apiKey)
        ]

        guard let url = components?.url else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode)
            else { return nil }

            let decoded = try JSONDecoder().decode(OMDbResponse.self, from: data)

            let imdb = MetadataPreferences.showIMDb ? Double(decoded.imdbRating ?? "") : nil
            var tomatometer: Int?
            var metacritic: Int?

            for rating in decoded.ratings ?? [] {
                if rating.source == "Rotten Tomatoes", MetadataPreferences.showTomatometer {
                    tomatometer = Int(rating.value.replacingOccurrences(of: "%", with: ""))
                } else if rating.source == "Metacritic", MetadataPreferences.showMetacritic {
                    let numeric = rating.value.split(separator: "/").first.map(String.init)
                    metacritic = numeric.flatMap(Int.init)
                }
            }

            return (imdb, tomatometer, metacritic)
        } catch {
            return nil
        }
    }

    // MARK: - Trakt

    private struct TraktRatingResponse: Decodable {
        var rating: Double
    }

    private static func fetchTraktRating(id: String, kind: String) async -> Double? {
        guard MetadataPreferences.showTrakt else { return nil }

        let client = await TraktStore.shared.client
        guard await client.isConfigured else { return nil }

        do {
            let response: TraktRatingResponse = try await client.publicRequest("\(kind)/\(id)/ratings")
            return response.rating
        } catch {
            return nil
        }
    }

    // MARK: - MyAnimeList (via Jikan)

    private struct JikanSearchResponse: Decodable {
        struct Anime: Decodable {
            var title: String
            var titleEnglish: String?
            var score: Double?

            enum CodingKeys: String, CodingKey {
                case title
                case titleEnglish = "title_english"
                case score
            }
        }

        var data: [Anime]
    }

    private static func fetchMALRating(title: String) async -> Double? {
        guard MetadataPreferences.showMAL else { return nil }

        let target = normalizedAnimeTitle(title)
        guard !target.isEmpty else { return nil }

        var components = URLComponents(string: "https://api.jikan.moe/v4/anime")
        components?.queryItems = [
            URLQueryItem(name: "q", value: title),
            URLQueryItem(name: "limit", value: "5")
        ]
        guard let url = components?.url else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode)
            else { return nil }

            let decoded = try JSONDecoder().decode(JikanSearchResponse.self, from: data)

            // Enkel een exacte titelovereenkomst (na normalisatie) gebruiken: Jikan's
            // zoekresultaten zijn fuzzy, en voor een niet-anime titel zou een los
            // matchend resultaat een compleet willekeurige score tonen.
            let match = decoded.data.first {
                normalizedAnimeTitle($0.title) == target
                    || normalizedAnimeTitle($0.titleEnglish ?? "") == target
            }
            return match?.score
        } catch {
            return nil
        }
    }

    private static func normalizedAnimeTitle(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
