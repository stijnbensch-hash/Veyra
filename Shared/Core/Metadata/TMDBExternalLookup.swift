import Foundation

/// Zoekt een TMDB-ID op basis van een IMDb-ID, voor plank-bronnen die zelf
/// geen TMDB-ID leveren (addon-catalogi zoals AIOMetadata, mediaservers
/// zonder `ProviderIds.Tmdb`) maar wel een IMDb-ID — zodat zulke items
/// alsnog aan de bestaande detailschermen gelinkt kunnen worden, die op
/// TMDB-ID werken (zie `ShelfItemDestination`).
enum TMDBExternalLookup {
    static func tmdbID(forIMDbID imdbID: String, kind: ShelfMediaKind) async -> Int? {
        guard let token = AppConfiguration.tmdbReadAccessToken else { return nil }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.themoviedb.org"
        components.path = "/3/find/\(imdbID)"
        components.queryItems = [
            URLQueryItem(name: "external_source", value: "imdb_id"),
            URLQueryItem(name: "language", value: CatalogLocalization.language)
        ]

        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode)
            else { return nil }

            let result = try JSONDecoder().decode(TMDBFindResult.self, from: data)
            return kind == .movie ? result.movieResults.first?.id : result.tvResults.first?.id
        } catch {
            return nil
        }
    }

    private struct TMDBFindResult: Decodable {
        let movieResults: [TMDBFindItem]
        let tvResults: [TMDBFindItem]

        enum CodingKeys: String, CodingKey {
            case movieResults = "movie_results"
            case tvResults = "tv_results"
        }
    }

    private struct TMDBFindItem: Decodable {
        let id: Int
    }

    /// Vangnet als er geen (bruikbare) IMDb-ID is: zoekt op titel via TMDB's
    /// eigen zoekfunctie en pakt het eerste resultaat. Minder betrouwbaar dan
    /// een ID-opzoeking (kan bij een generieke titel mis grijpen), maar beter
    /// dan een item dat helemaal niet naar TMDB gelinkt is — vooral nodig
    /// voor mediaserver-bronnen (VeyraHub) die vooralsnog geen `ProviderIds`
    /// meesturen voor al hun bibliotheken.
    static func tmdbID(forTitle title: String, year: Int? = nil, kind: ShelfMediaKind) async -> Int? {
        guard let token = AppConfiguration.tmdbReadAccessToken else { return nil }

        do {
            if kind == .movie {
                let results = try await TMDBClient(readAccessToken: token).searchMovies(query: title)
                return bestMatch(results.map { ($0.id, $0.releaseDate) }, year: year)
            } else if let service = SeriesService() {
                let results = try await service.searchSeries(query: title)
                return bestMatch(results.map { ($0.id, $0.firstAirDate) }, year: year)
            }
            return nil
        } catch {
            return nil
        }
    }

    /// Verkiest, als er een jaartal bekend is, het eerste zoekresultaat
    /// waarvan het release-/uitzendjaar overeenkomt — zonder dit kon een
    /// titel-zoekopdracht een compleet andere, gelijknamige of populairdere
    /// titel als eerste resultaat teruggeven en dus de verkeerde titel
    /// linken. Zonder jaartal (of geen match erop) gewoon het eerste
    /// resultaat, zoals TMDB ze op relevantie sorteert.
    private static func bestMatch(_ candidates: [(Int, String?)], year: Int?) -> Int? {
        guard !candidates.isEmpty else { return nil }

        if let year {
            if let matched = candidates.first(where: { _, date in
                guard let date, date.count >= 4 else { return false }
                return Int(date.prefix(4)) == year
            }) {
                return matched.0
            }
        }

        return candidates.first?.0
    }
}
