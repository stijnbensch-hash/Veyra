import Foundation

struct WatchProvider: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let logoPath: String?
    let priority: Int?
    enum CodingKeys: String, CodingKey {
        case id = "provider_id", name = "provider_name", logoPath = "logo_path", priority = "display_priority"
    }
    var logoURL: URL? {
        guard let logoPath, !logoPath.isEmpty else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/original")?.appendingPathComponent(logoPath.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    }
}

struct WatchProviderPage: Decodable { let results: [WatchProvider] }
enum ProviderMediaKind: String { case movie, tv }

extension TMDBClient {
    func watchProviders(kind: ProviderMediaKind, region: String) async throws -> [WatchProvider] {
        let all: WatchProviderPage = try await request(path: "/3/watch/providers/\(kind.rawValue)")
        let regional: WatchProviderPage = try await request(path: "/3/watch/providers/\(kind.rawValue)", queryItems: [
            URLQueryItem(name: "watch_region", value: region)
        ])
        // Exactly the user's thirteen brands, in their requested order. Prefer the
        // regional ID when TMDB has multiple direct-service entries for a brand.
        let brands: [[Int]] = [
            [8], [9, 119], [337, 122], [1899], [350], [531], [15],
            [386, 387], [99], [524, 510, 520], [43], [34], [526]
        ]
        return brands.compactMap { ids in
            ids.compactMap { id in regional.results.first { $0.id == id } }.first
                ?? ids.compactMap { id in all.results.first { $0.id == id } }.first
        }
    }

    /// Maximaal aantal items dat per streamingdienst wordt opgehaald (5 TMDB-pagina's à 20 items).
    private static let maxProviderResultPages = 5

    func movies(providerID: Int, region: String) async throws -> [TMDBMovie] {
        var results: [TMDBMovie] = []
        for page in 1...Self.maxProviderResultPages {
            let response: TMDBMoviePage = try await request(
                path: "/3/discover/movie",
                queryItems: providerQuery(providerID, region: region, sortBy: "primary_release_date.desc", page: page)
            )
            results.append(contentsOf: response.results)
            if response.results.count < 20 { break }
        }
        return Array(results.prefix(100))
    }

    func series(providerID: Int, region: String) async throws -> [TMDBSeries] {
        var results: [TMDBSeries] = []
        for page in 1...Self.maxProviderResultPages {
            let response: TMDBSeriesPage = try await request(
                path: "/3/discover/tv",
                queryItems: providerQuery(providerID, region: region, sortBy: "first_air_date.desc", page: page)
            )
            results.append(contentsOf: response.results)
            if response.results.count < 20 { break }
        }
        return Array(results.prefix(100))
    }

    private func providerQuery(_ id: Int, region: String, sortBy: String, page: Int) -> [URLQueryItem] {
        [URLQueryItem(name: "with_watch_providers", value: String(id)),
         URLQueryItem(name: "watch_region", value: region),
         URLQueryItem(name: "sort_by", value: sortBy),
         URLQueryItem(name: "include_adult", value: "false"),
         URLQueryItem(name: "page", value: String(page))]
    }
}
