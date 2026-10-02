import Foundation

/// Fase 10 (TMDB-spec, Diagnostics/Polish §63/§65): lichte, in-memory sessietellers voor
/// TMDB-verkeer. Spec §65 noemt een debug-dashboard zelf "optioneel" -- dit levert de tellingen
/// + een DEBUG-logregel per gebeurtenis (spec §63/§64), zonder een aparte dashboard-UI te bouwen.
/// `summary()` kan desgewenst later aan een bestaand instellingen-/debugscherm gehangen worden.
actor TMDBDiagnostics {
    static let shared = TMDBDiagnostics()

    private(set) var requestsStarted = 0
    private(set) var requestsCoalesced = 0
    private(set) var memoryCacheHits = 0
    private(set) var rateLimited429Count = 0
    private(set) var timeoutCount = 0

    private init() {}

    func recordRequestStarted() { requestsStarted += 1 }
    func recordCoalesced() { requestsCoalesced += 1 }
    func recordCacheHit() { memoryCacheHits += 1 }
    func recordRateLimited() { rateLimited429Count += 1 }
    func recordTimeout() { timeoutCount += 1 }

    /// Spec §65: "requests/session, coalesced, memory cache hit %, 429 count, timeout count" --
    /// enkel voor DEBUG-gebruik.
    func summary() -> String {
        let total = requestsStarted + requestsCoalesced + memoryCacheHits
        let hitRate = total > 0 ? Int((Double(memoryCacheHits) / Double(total)) * 100) : 0
        return "[TMDB] diagnostics requests=\(requestsStarted) coalesced=\(requestsCoalesced) " +
            "cacheHits=\(memoryCacheHits) (\(hitRate)%) 429=\(rateLimited429Count) timeouts=\(timeoutCount)"
    }
}
