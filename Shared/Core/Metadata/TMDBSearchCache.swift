import Foundation

/// Fase 7 (TMDB-spec, Search §42) + Fase 8 (Collections §45): korte, in-memory cache voor
/// response-`Data` ná een voltooide (niet meer in-flight) TMDB-aanvraag -- voorkomt een nieuwe
/// aanvraag wanneer dezelfde request kort na elkaar opnieuw gedaan wordt (bv. debounce-her-
/// trigger, terugnavigeren naar Zoeken of een Collection-detail, snel wisselen tussen velden).
/// Per entry een eigen TTL (spec §60: niet alles dezelfde TTL -- zoekresultaten korter dan
/// collectiedetails). Geen tweede cachesysteem naast `TMDBRequestCoordinator`/`URLCache`: dit
/// vult enkel het gat ná een voltooide aanvraag, `TMDBClient`/`SeriesService` zijn de enige
/// aanroepers (via hun gedeelde `request(path:queryItems:cacheKey:cacheTTL:)`).
actor TMDBSearchCache {
    static let shared = TMDBSearchCache()

    static let defaultTTL: TimeInterval = 45
    /// Collectiedetails/parts wijzigen zelden (spec §45) -- vergelijkbaar met de "long" tier
    /// voor film/serie-details (spec §60).
    static let longTTL: TimeInterval = 6 * 60 * 60

    private struct Entry {
        let data: Data
        let storedAt: Date
        let ttl: TimeInterval
    }

    private var entries: [String: Entry] = [:]

    private init() {}

    func data(for key: String) async -> Data? {
        guard let entry = entries[key] else { return nil }
        guard Date().timeIntervalSince(entry.storedAt) < entry.ttl else {
            entries[key] = nil
            return nil
        }
        #if DEBUG
        print("[TMDB] \(key) cache=memory")
        #endif
        await TMDBDiagnostics.shared.recordCacheHit()
        return entry.data
    }

    func store(_ data: Data, for key: String, ttl: TimeInterval = TMDBSearchCache.defaultTTL) {
        entries[key] = Entry(data: data, storedAt: Date(), ttl: ttl)
    }
}
