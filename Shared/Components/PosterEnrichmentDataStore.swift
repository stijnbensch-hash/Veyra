// PosterEnrichmentDataStore.swift — gedeeld (iOS + tvOS)
// Databronnen voor "Posterverrijking → Better Posters" naast Genre/Beoordeling (die al bestonden):
// Trendlabels (TMDB trending + rangschikking, à la BetterPoster's "Trending"/"New"/"#3"),
// Leeftijdsclassificatie (TMDB release_dates/content_ratings) en Resterende afleveringen
// (Trakt-voortgang). Eén gedeelde, in-memory cache per sessie zodat een posterrooster niet
// telkens opnieuw dezelfde titel bevraagt.

import Foundation

@MainActor
final class PosterEnrichmentDataStore: ObservableObject {
    static let shared = PosterEnrichmentDataStore()
    private init() {}

    // MARK: Trending / rangschikking

    // Volgorde blijft bewaard (TMDB levert al gesorteerd op populariteit) zodat de index de
    // rangschikking geeft — index 0 is "#1".
    private var trendingMovieOrder: [Int] = []
    private var trendingTVOrder: [Int] = []
    private var trendingLoadedAt: Date?
    private var trendingLoadTask: Task<Void, Never>?

    /// True als deze titel vandaag/deze week trending is op TMDB. Laadt de trendinglijst
    /// (één keer per sessie, ververst na een uur) op de achtergrond; tot die klaar is levert
    /// dit gewoon `false` — de badge verschijnt dan zodra de lijst binnen is.
    func isTrending(id: Int, isMovie: Bool) -> Bool {
        loadTrendingIfNeeded()
        return (isMovie ? trendingMovieOrder : trendingTVOrder).contains(id)
    }

    /// 1-gebaseerde positie in de trendinglijst van vandaag, bv. `3` voor "#3". `nil` als de
    /// titel niet (meer) trending is.
    func trendingRank(id: Int, isMovie: Bool) -> Int? {
        loadTrendingIfNeeded()
        guard let index = (isMovie ? trendingMovieOrder : trendingTVOrder).firstIndex(of: id) else { return nil }
        return index + 1
    }

    private func loadTrendingIfNeeded() {
        if let trendingLoadedAt, Date().timeIntervalSince(trendingLoadedAt) < 3600 { return }
        guard trendingLoadTask == nil else { return }
        guard let token = AppConfiguration.tmdbReadAccessToken else { return }
        trendingLoadTask = Task { [weak self] in
            guard let self else { return }
            let client = TMDBClient(readAccessToken: token)
            async let movies: [TMDBMovie]? = try? client.trendingMovies(window: "day")
            async let shows: TMDBTrendingTVPage? = try? client.request(path: "/3/trending/tv/day")
            let (movieResults, showResult) = await (movies, shows)
            self.trendingMovieOrder = (movieResults ?? []).map(\.id)
            self.trendingTVOrder = (showResult?.results ?? []).map(\.id)
            self.trendingLoadedAt = Date()
            self.trendingLoadTask = nil
        }
    }

    // MARK: Leeftijdsclassificatie

    private var certificationCache: [String: String] = [:]
    private var certificationInFlight: Set<String> = []

    /// Cachet resultaat (mogelijk `nil` = "geen classificatie gevonden") zodat dezelfde titel
    /// niet telkens opnieuw bevraagd wordt. Roep dit vanuit `.task(id:)` op de poster aan.
    func certification(movieID id: Int) async -> String? {
        await certification(key: "movie:\(id)") { token in
            let entries: TMDBReleaseDatesResponse = try await TMDBClient(readAccessToken: token)
                .request(path: "/3/movie/\(id)/release_dates")
            return Self.pickCertification(entries.results.map { ($0.iso31661, $0.releaseDates.compactMap { $0.certification }) })
        }
    }

    func certification(tvID id: Int) async -> String? {
        await certification(key: "tv:\(id)") { token in
            let entries: TMDBContentRatingsResponse = try await TMDBClient(readAccessToken: token)
                .request(path: "/3/tv/\(id)/content_ratings")
            return Self.pickCertification(entries.results.map { ($0.iso31661, [$0.rating].compactMap { $0 }) })
        }
    }

    private func certification(key: String, fetch: (String) async throws -> String?) async -> String? {
        if let cached = certificationCache[key] { return cached.isEmpty ? nil : cached }
        guard !certificationInFlight.contains(key) else { return nil }
        guard let token = AppConfiguration.tmdbReadAccessToken else { return nil }
        certificationInFlight.insert(key)
        defer { certificationInFlight.remove(key) }
        let value = (try? await fetch(token)) ?? nil
        certificationCache[key] = value ?? ""
        return value
    }

    /// Nederlandse classificatie als die er is, anders Amerikaanse, anders de eerste niet-lege waarde.
    private static func pickCertification(_ entries: [(country: String, values: [String])]) -> String? {
        func firstValue(_ country: String) -> String? {
            entries.first { $0.country == country }?.values.first { !$0.isEmpty }
        }
        return firstValue("NL") ?? firstValue("US") ?? entries.flatMap(\.values).first { !$0.isEmpty }
    }
}

// MARK: - TMDB-responsemodellen (enkel de velden die hier nodig zijn)

private struct TMDBTrendingTVPage: Decodable { let results: [TMDBTrendingTVResult] }
private struct TMDBTrendingTVResult: Decodable { let id: Int }

private struct TMDBReleaseDatesResponse: Decodable {
    struct Entry: Decodable {
        let iso31661: String
        let releaseDates: [ReleaseDate]
        enum CodingKeys: String, CodingKey { case iso31661 = "iso_3166_1", releaseDates = "release_dates" }
    }
    struct ReleaseDate: Decodable {
        let certification: String?
    }
    let results: [Entry]
}

private struct TMDBContentRatingsResponse: Decodable {
    struct Entry: Decodable {
        let iso31661: String
        let rating: String?
        enum CodingKeys: String, CodingKey { case iso31661 = "iso_3166_1", rating }
    }
    let results: [Entry]
}
