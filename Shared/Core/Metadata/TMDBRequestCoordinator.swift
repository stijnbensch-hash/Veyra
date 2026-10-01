// TMDBRequestCoordinator.swift — gedeeld (tvOS/iOS/iPadOS/macOS)
// Fase 2 ("VEYRA — TMDB PERFORMANCE & CACHING REFACTOR" spec §4/§10/§11/§20/§35/§36/§37/§38):
// centrale request-foundation voor TMDB -- single-flight/dedup, een passend geconfigureerde
// `URLSession`/`URLCache`, begrensde timeouts, bounded retry met backoff+jitter op tijdelijke
// fouten, en het respecteren van 429/Retry-After. Vervangt NIET de bestaande per-endpoint
// clients (`TMDBClient`/`SeriesService`/...) -- die blijven hun eigen paden/modellen bouwen,
// maar sturen hun HTTP-werk voortaan via deze ene gedeelde coordinator, zodat twee callers die
// toevallig tegelijk hetzelfde endpoint bevragen maar 1 HTTP-request op de kabel zetten.

import Foundation

enum TMDBCoordinatorError: Error {
    case invalidResponse
    case httpError(statusCode: Int)
    case rateLimited(retryAfter: TimeInterval?)
}

actor TMDBRequestCoordinator {
    static let shared = TMDBRequestCoordinator()

    /// Gedeelde sessie voor AL het TMDB-verkeer -- één `URLCache` (spec §9/§10: HTTP-cachelaag),
    /// begrensde timeouts (spec §38: TMDB mag Detail/Home niet eindeloos blokkeren) i.p.v. de
    /// vorige losse `URLSession.shared`-aanroepen zonder enige configuratie.
    let session: URLSession

    private var inFlight: [String: Task<Data, Error>] = [:]
    /// Na een 429 met `Retry-After` wordt nieuw TMDB-verkeer tot dit tijdstip geweigerd (spec
    /// §35/§36), i.p.v. iedere caller zelf tegen de limiet te laten oplopen.
    private var blockedUntil: Date?

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(
            memoryCapacity: 20 * 1024 * 1024,
            diskCapacity: 150 * 1024 * 1024
        )
        configuration.requestCachePolicy = .useProtocolCachePolicy
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        session = URLSession(configuration: configuration)
    }

    /// Haalt data op voor `request`, gededupliceerd op `key` (normaal gesproken de volledige
    /// URL, incl. querystring -- zie de aanroepers). Een tweede aanvraag met dezelfde key terwijl
    /// de eerste nog loopt deelt gewoon dezelfde `Task` i.p.v. een tweede HTTP-request te starten
    /// (spec §3/§4: "mag er maar 1 HTTP request lopen").
    func data(for request: URLRequest, key: String) async throws -> Data {
        if let blockedUntil, Date() < blockedUntil {
            #if DEBUG
            print("[TMDB] rateLimited blockedUntil=\(blockedUntil)")
            #endif
            throw TMDBCoordinatorError.rateLimited(retryAfter: blockedUntil.timeIntervalSinceNow)
        }

        if let existing = inFlight[key] {
            #if DEBUG
            print("[TMDB] request coalesced key=\(key)")
            #endif
            return try await existing.value
        }

        let session = self.session
        let task = Task<Data, Error> {
            try await Self.performWithRetry(session: session, request: request)
        }
        inFlight[key] = task
        defer { inFlight[key] = nil }

        do {
            return try await task.value
        } catch let error as TMDBCoordinatorError {
            if case .rateLimited(let retryAfter) = error {
                blockedUntil = Date().addingTimeInterval(retryAfter ?? 5)
            }
            throw error
        }
    }

    /// Max 3 pogingen, enkel op tijdelijke fouten (timeout/429/5xx, spec §37) met oplopende
    /// backoff + jitter -- nooit op een gewone 4xx (verkeerde aanvraag blijft verkeerd).
    private static let maxAttempts = 3

    private static func performWithRetry(session: URLSession, request: URLRequest) async throws -> Data {
        var attempt = 0
        while true {
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw TMDBCoordinatorError.invalidResponse
                }

                if http.statusCode == 429 {
                    let retryAfter = retryAfterSeconds(from: http)
                    if attempt < maxAttempts - 1 {
                        #if DEBUG
                        print("[TMDB] 429 retryAfter=\(retryAfter ?? -1) attempt=\(attempt)")
                        #endif
                        try await Task.sleep(
                            nanoseconds: UInt64((retryAfter ?? backoffDelay(attempt: attempt)) * 1_000_000_000))
                        attempt += 1
                        continue
                    }
                    throw TMDBCoordinatorError.rateLimited(retryAfter: retryAfter)
                }

                if (500...504).contains(http.statusCode), attempt < maxAttempts - 1 {
                    try await Task.sleep(nanoseconds: UInt64(backoffDelay(attempt: attempt) * 1_000_000_000))
                    attempt += 1
                    continue
                }

                guard (200...299).contains(http.statusCode) else {
                    throw TMDBCoordinatorError.httpError(statusCode: http.statusCode)
                }

                return data
            } catch let urlError as URLError where urlError.code == .timedOut && attempt < maxAttempts - 1 {
                #if DEBUG
                print("[TMDB] timeout attempt=\(attempt)")
                #endif
                try? await Task.sleep(nanoseconds: UInt64(backoffDelay(attempt: attempt) * 1_000_000_000))
                attempt += 1
                continue
            }
        }
    }

    private static func backoffDelay(attempt: Int) -> Double {
        pow(2.0, Double(attempt)) + Double.random(in: 0...0.3)
    }

    private static func retryAfterSeconds(from response: HTTPURLResponse) -> TimeInterval? {
        guard let value = response.value(forHTTPHeaderField: "Retry-After") else { return nil }
        return TimeInterval(value)
    }

    // MARK: - Configuration (spec §20/§60: "very long" TTL, basis voor de image-URL-builder
    // van Fase 5)

    private var cachedConfiguration: TMDBConfigurationImages?

    /// `/configuration` hoeft maar één keer per sessie opgehaald te worden (spec §20: "mag niet
    /// telkens opnieuw opgehaald worden"). Nog niet aangesloten op een aanroeper -- dat gebeurt
    /// in Fase 5 bij de gecentraliseerde image-URL-builder.
    func configuration(token: String) async throws -> TMDBConfigurationImages {
        if let cachedConfiguration { return cachedConfiguration }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.themoviedb.org"
        components.path = "/3/configuration"
        guard let url = components.url else { throw TMDBCoordinatorError.invalidResponse }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data = try await self.data(for: request, key: url.absoluteString)
        let decoded = try JSONDecoder().decode(TMDBConfigurationResponse.self, from: data)
        cachedConfiguration = decoded.images
        #if DEBUG
        print("[TMDB] configuration cached")
        #endif
        return decoded.images
    }
}

/// Relevante velden van TMDB's `/configuration`-respons (spec §20) -- de basis voor een
/// centrale `TMDBImageURLBuilder` i.p.v. overal hardcoded `/original`/`w500`-strings (Fase 5).
struct TMDBConfigurationImages: Decodable, Sendable {
    let baseURL: String
    let secureBaseURL: String
    let posterSizes: [String]
    let backdropSizes: [String]
    let logoSizes: [String]
    let profileSizes: [String]

    enum CodingKeys: String, CodingKey {
        case baseURL = "base_url"
        case secureBaseURL = "secure_base_url"
        case posterSizes = "poster_sizes"
        case backdropSizes = "backdrop_sizes"
        case logoSizes = "logo_sizes"
        case profileSizes = "profile_sizes"
    }
}

private struct TMDBConfigurationResponse: Decodable {
    let images: TMDBConfigurationImages
}
