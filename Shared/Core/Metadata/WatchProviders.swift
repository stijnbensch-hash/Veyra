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

    /// Maximaal aantal items dat per bevraging wordt opgehaald (5 TMDB-pagina's à 20 items).
    private static let maxProviderResultPages = 5

    /// Films ontdekken via TMDB's discover-endpoint, optioneel gefilterd op
    /// streamingdienst, genre, decennium (jarenbereik) en minimale
    /// beoordeling. Alle parameters zijn optioneel en kunnen vrij worden
    /// gecombineerd; wordt er niets meegegeven dan komt dit overeen met
    /// "populair" (sortering op releasedatum, nieuwste eerst).
    func movies(
        providerID: Int? = nil,
        region: String,
        genreID: Int? = nil,
        minimumYear: Int? = nil,
        maximumYear: Int? = nil,
        minimumRating: Double? = nil
    ) async throws -> [TMDBMovie] {
        var results: [TMDBMovie] = []
        for page in 1...Self.maxProviderResultPages {
            let response: TMDBMoviePage = try await request(
                path: "/3/discover/movie",
                queryItems: discoverQuery(
                    providerID: providerID,
                    region: region,
                    genreID: genreID,
                    minimumYear: minimumYear,
                    maximumYear: maximumYear,
                    minimumRating: minimumRating,
                    sortBy: "primary_release_date.desc",
                    dateGTEKey: "primary_release_date.gte",
                    dateLTEKey: "primary_release_date.lte",
                    page: page
                )
            )
            results.append(contentsOf: response.results)
            if response.results.count < 20 { break }
        }
        return Array(results.filter { TMDBCatalogLanguageFilter.allows($0.originalLanguage) }.prefix(100))
    }

    /// Series ontdekken via TMDB's discover-endpoint — zie `movies(...)` hierboven.
    func series(
        providerID: Int? = nil,
        region: String,
        genreID: Int? = nil,
        minimumYear: Int? = nil,
        maximumYear: Int? = nil,
        minimumRating: Double? = nil
    ) async throws -> [TMDBSeries] {
        var results: [TMDBSeries] = []
        for page in 1...Self.maxProviderResultPages {
            let response: TMDBSeriesPage = try await request(
                path: "/3/discover/tv",
                queryItems: discoverQuery(
                    providerID: providerID,
                    region: region,
                    genreID: genreID,
                    minimumYear: minimumYear,
                    maximumYear: maximumYear,
                    minimumRating: minimumRating,
                    sortBy: "first_air_date.desc",
                    dateGTEKey: "first_air_date.gte",
                    dateLTEKey: "first_air_date.lte",
                    page: page
                )
            )
            results.append(contentsOf: response.results)
            if response.results.count < 20 { break }
        }
        return Array(results.filter { TMDBCatalogLanguageFilter.allows($0.originalLanguage) }.prefix(100))
    }

    private func discoverQuery(
        providerID: Int?,
        region: String,
        genreID: Int?,
        minimumYear: Int?,
        maximumYear: Int?,
        minimumRating: Double?,
        sortBy: String,
        dateGTEKey: String,
        dateLTEKey: String,
        page: Int
    ) -> [URLQueryItem] {
        var items = [
            URLQueryItem(name: "sort_by", value: sortBy),
            URLQueryItem(name: "include_adult", value: "false"),
            URLQueryItem(name: "page", value: String(page))
        ]

        if let providerID {
            items.append(URLQueryItem(name: "with_watch_providers", value: String(providerID)))
            items.append(URLQueryItem(name: "watch_region", value: region))
        }

        if let genreID {
            items.append(URLQueryItem(name: "with_genres", value: String(genreID)))
        }

        if let minimumYear {
            items.append(URLQueryItem(name: dateGTEKey, value: "\(minimumYear)-01-01"))
        }

        if let maximumYear {
            items.append(URLQueryItem(name: dateLTEKey, value: "\(maximumYear)-12-31"))
        }

        if let minimumRating {
            items.append(URLQueryItem(name: "vote_average.gte", value: String(minimumRating)))
            // Voorkomt dat nauwelijks-bekeken titels met een toevallige hoge score bovenaan komen.
            items.append(URLQueryItem(name: "vote_count.gte", value: "20"))
        }

        return items
    }
}
