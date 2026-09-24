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
}
