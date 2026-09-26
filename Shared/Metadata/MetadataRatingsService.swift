import Foundation

/// Haalt de ratings op die op een film- of seriepagina getoond worden,
/// voor de bronnen die de gebruiker heeft ingeschakeld in
/// Instellingen → Metadata:
/// - TMDB komt rechtstreeks van TMDB zelf (geen extra sleutel nodig).
/// - IMDb, Tomatometer en Metacritic komen van OMDb (vereist een gratis
///   API-sleutel van omdbapi.com, in te stellen via Account of Secrets.xcconfig).
/// - Trakt komt van Trakt's publieke ratings-endpoint (geen aanmelding nodig,
///   enkel de al aanwezige Trakt Client ID/Secret).
/// - Popcornmeter (de publieksscore van Rotten Tomatoes), Letterboxd en
///   MyAnimeList hebben geen publiek toegankelijke API die hier is
///   aangesloten en blijven daarom altijd leeg.
enum MetadataRatingsService {
    // MARK: - Public

    static func movieRatings(tmdbID: Int, imdbID: String?) async -> MetadataRatings {
        let tmdbValue = await fetchTMDBMovieRating(tmdbID: tmdbID)
        let omdbValue = await fetchOMDb(imdbID: imdbID)
        let traktID = (imdbID?.isEmpty == false) ? imdbID! : String(tmdbID)
        let traktValue = await fetchTraktRating(id: traktID, kind: "movies")

        return MetadataRatings(
            imdb: omdbValue?.imdb,
            tmdb: tmdbValue,
            tomatometer: omdbValue?.tomatometer,
            metacritic: omdbValue?.metacritic,
            trakt: traktValue,
            popcornmeter: nil,
            letterboxd: nil,
            mal: nil
        )
    }

    static func seriesRatings(tmdbID: Int, imdbID: String?) async -> MetadataRatings {
        let resolvedImdbID: String?
        if let imdbID, !imdbID.isEmpty {
            resolvedImdbID = imdbID
        } else {
            resolvedImdbID = await resolveSeriesImdbID(tmdbID: tmdbID)
        }

        let tmdbValue = await fetchTMDBSeriesRating(tmdbID: tmdbID)
        let omdbValue = await fetchOMDb(imdbID: resolvedImdbID)
        let traktID = (resolvedImdbID?.isEmpty == false) ? resolvedImdbID! : String(tmdbID)
        let traktValue = await fetchTraktRating(id: traktID, kind: "shows")

        return MetadataRatings(
            imdb: omdbValue?.imdb,
            tmdb: tmdbValue,
            tomatometer: omdbValue?.tomatometer,
            metacritic: omdbValue?.metacritic,
            trakt: traktValue,
            popcornmeter: nil,
            letterboxd: nil,
            mal: nil
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
}
