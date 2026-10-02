import Foundation

/// Zoekt een TMDB-ID op basis van een IMDb-ID, voor plank-bronnen die zelf
/// geen TMDB-ID leveren (addon-catalogi zoals AIOMetadata, mediaservers
/// zonder `ProviderIds.Tmdb`) maar wel een IMDb-ID — zodat zulke items
/// alsnog aan de bestaande detailschermen gelinkt kunnen worden, die op
/// TMDB-ID werken (zie `ShelfItemDestination`).
enum TMDBExternalLookup {
    /// Fase 9 (IPTV-mapping §50/§51/§52): centrale ingang die eerst `IPTVTMDBMappingCache`
    /// raadpleegt (geen hernieuwde TMDB-aanvraag voor een al bekende mapping, positief of
    /// negatief) en pas bij een cache-miss de IMDb- en vervolgens titel-opzoeking doet, waarna
    /// het resultaat (ook een "niet gevonden") teruggeschreven wordt naar de cache. Vervangt de
    /// losse IMDb-/titel-aanroepen + eigen cache-logica die voorheen in `ShelfCatalogService`
    /// zaten.
    static func tmdbID(
        forIMDbID imdbID: String?, title: String, year: Int?, kind: ShelfMediaKind,
        preferredOriginalLanguage: String? = nil
    ) async -> Int? {
        if case .some(let cached) = await IPTVTMDBMappingCache.shared.cachedTMDBID(
            imdbID: imdbID, title: title, year: year, kind: kind
        ) {
            return cached
        }

        var found: Int?
        if let imdbID, !imdbID.isEmpty {
            found = await tmdbID(forIMDbID: imdbID, kind: kind)
        }
        if found == nil {
            found = await tmdbID(forTitle: title, year: year, kind: kind, preferredOriginalLanguage: preferredOriginalLanguage)
        }

        await IPTVTMDBMappingCache.shared.store(tmdbID: found, imdbID: imdbID, title: title, year: year, kind: kind)
        return found
    }

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
            // Fase 9: ook deze aanroep via de gedeelde coordinator (Fase 2) i.p.v. een losse
            // `URLSession.shared.data(for:)` -- zelfde single-flight/retry/429-afhandeling.
            let data = try await TMDBRequestCoordinator.shared.data(for: request, key: url.absoluteString)
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
    static func tmdbID(
        forTitle title: String, year: Int? = nil, kind: ShelfMediaKind,
        preferredOriginalLanguage: String? = nil
    ) async -> Int? {
        guard let token = AppConfiguration.tmdbReadAccessToken else { return nil }

        do {
            if kind == .movie {
                let page = try await TMDBClient(readAccessToken: token).searchMovies(query: title)
                return bestMatch(
                    page.results.map { ($0.id, $0.releaseDate, $0.originalLanguage) },
                    year: year, preferredOriginalLanguage: preferredOriginalLanguage
                )
            } else if let service = SeriesService() {
                let page = try await service.searchSeries(query: title)
                return bestMatch(
                    page.results.map { ($0.id, $0.firstAirDate, $0.originalLanguage) },
                    year: year, preferredOriginalLanguage: preferredOriginalLanguage
                )
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
    /// linken. Als er GEEN jaartal-match is (bv. een regionale release van een
    /// NIEUW SEIZOEN van een al langer lopende reeks -- de uitzenddatum van dat
    /// seizoen is geen betrouwbare schatting van TMDB's `firstAirDate`, dus
    /// bewust geen jaartal meegegeven door de aanroeper) valt dit terug op een
    /// `preferredOriginalLanguage`-voorkeur (bv. "nl" voor een Vlaamse bron) vóór
    /// de blinde TMDB-relevantievolgorde -- vermindert het risico dat een
    /// generieke titel (bv. "Switch") een compleet andere, populairdere
    /// buitenlandse titel linkt. Zonder jaartal/taal-match gewoon het eerste
    /// resultaat, zoals TMDB ze op relevantie sorteert.
    private static func bestMatch(
        _ candidates: [(Int, String?, String?)], year: Int?, preferredOriginalLanguage: String? = nil
    ) -> Int? {
        guard !candidates.isEmpty else { return nil }

        if let year {
            if let matched = candidates.first(where: { _, date, _ in
                guard let date, date.count >= 4 else { return false }
                return Int(date.prefix(4)) == year
            }) {
                return matched.0
            }
        }

        if let preferredOriginalLanguage {
            if let matched = candidates.first(where: { _, _, language in
                language?.caseInsensitiveCompare(preferredOriginalLanguage) == .orderedSame
            }) {
                return matched.0
            }
        }

        return candidates.first?.0
    }
}
