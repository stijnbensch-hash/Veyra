import Foundation

/// Eén tijdsegment (in seconden), zoals TheIntroDB het teruggeeft. `start`
/// kan ontbreken (segment begint bij het begin van de aflevering/film) en
/// `end` kan ontbreken (segment loopt door tot het einde).
struct IntroDBSegment: Equatable {
    var start: Double?
    var end: Double?

    func contains(_ time: Double) -> Bool {
        if let start, time < start { return false }
        if let end, time >= end { return false }
        return start != nil || end != nil
    }
}

/// Intro-/recap-/aftiteling-/preview-segmenten voor één film of aflevering,
/// zoals opgehaald bij TheIntroDB (zie `IntroDBClient`). Alle tijden in
/// seconden vanaf het begin van de video.
struct IntroDBSegments: Equatable {
    var intros: [IntroDBSegment] = []
    var recaps: [IntroDBSegment] = []
    var creditsSegments: [IntroDBSegment] = []
    var previews: [IntroDBSegment] = []

    var intro: IntroDBSegment? { intros.first }
    var recap: IntroDBSegment? { recaps.first }
    var credits: IntroDBSegment? { creditsSegments.first }
    var preview: IntroDBSegment? { previews.first }

    static let empty = IntroDBSegments()
}

/// Client voor TheIntroDB (https://theintrodb.org) — een gratis, community
/// gevulde database met exacte start-/eindtijden om intro's, recaps,
/// aftitelingen en previews van films en series over te slaan. Gebruikt
/// dezelfde publieke `GET /v3/media`-endpoint als de officiële Jellyfin-
/// plugin (`api.theintrodb.org`). Zonder eigen API-sleutel (Instellingen →
/// Account → TheIntroDB) vallen aanvragen onder het anonieme rate limit
/// van ~30 verzoeken per 10 seconden -- ruim genoeg voor één opzoeking per
/// afspeelsessie, maar een eigen sleutel geeft een hoger limiet en voorkeur
/// bij matching, dus wordt meegestuurd zodra ingesteld.
///
/// Matcht bij voorkeur op TMDB-id (+ seizoen/aflevering voor series), of op
/// IMDb-id wanneer een titel nog geen TMDB-id heeft.
actor IntroDBClient {
    static let shared = IntroDBClient()

    private let baseURL = URL(string: "https://api.theintrodb.org/v3/media")!
    private let session: URLSession

    private struct CacheKey: Hashable {
        let identifier: String
        let season: Int?
        let episode: Int?
    }

    private struct CachedSegments {
        let value: IntroDBSegments
        let fetchedAt: Date
    }

    private var cache: [CacheKey: CachedSegments] = [:]
    private var inFlight: [CacheKey: Task<FetchResult, Never>] = [:]

    // Audit P0: een mislukte opzoeking (timeout/offline/429/5xx) is GEEN geldig
    // "geen segmenten"-antwoord en mag niet als zodanig gecached worden -- anders
    // duurt het bij een tijdelijke TheIntroDB-storing tot 10 minuten voor Veyra het
    // opnieuw probeert. `FetchResult` maakt dat onderscheid expliciet; alleen
    // `.success` (ook met lege arrays, of een bevestigde 404 "niet gevonden")
    // wordt in `cache` geschreven. Een 429 blokkeert nieuwe aanroepen tot
    // `Retry-After` is verstreken, zonder dat als lege cache te bewaren.
    enum FetchResult {
        case success(IntroDBSegments)
        case failure(retryAfter: TimeInterval?)
    }
    private var blockedUntil: Date?

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Haalt de skip-segmenten op voor een film (season/episode = nil) of
    /// een serie-aflevering. Geeft `.empty` terug bij elke fout, ontbrekende
    /// ID, "niet gevonden" of een rate limit — zodat een aanroeper
    /// zonder foutafhandeling gewoon geen skip-knoppen toont.
    func segments(
        tmdbID: Int?, imdbID: String? = nil,
        season: Int?, episode: Int?, durationSeconds: Double?
    ) async -> IntroDBSegments {
        switch await lookup(
            tmdbID: tmdbID, imdbID: imdbID,
            season: season, episode: episode, durationSeconds: durationSeconds
        ) {
        case .success(let segments): return segments
        case .failure: return .empty
        }
    }

    /// Zelfde opzoeking als `segments(...)`, maar geeft het echte resultaat
    /// terug inclusief het onderscheid tussen een bevestigd leeg antwoord en
    /// een mislukte poging -- voor aanroepers (zoals `VeyraSkipSegmentProvider`)
    /// die een storing willen doorgeven in plaats van laten verdwijnen in `.empty`.
    func lookup(
        tmdbID: Int?, imdbID: String? = nil,
        season: Int?, episode: Int?, durationSeconds: Double?
    ) async -> FetchResult {
        #if DEBUG
        // Nooit de key zelf loggen (spec §3/74) -- alleen of er een
        // geconfigureerd is.
        print("[SkipSegments][TheIntroDB] apiKeyConfigured=\(AppConfiguration.introDBAPIKey?.isEmpty == false)")
        #endif
        let identifier: String
        let idQueryItem: URLQueryItem
        if let tmdbID, tmdbID > 0 {
            identifier = "tmdb:\(tmdbID)"
            idQueryItem = URLQueryItem(name: "tmdb_id", value: String(tmdbID))
        } else if let imdbID = imdbID?.trimmingCharacters(in: .whitespacesAndNewlines),
                  imdbID.hasPrefix("tt"), imdbID.dropFirst(2).count >= 7,
                  imdbID.dropFirst(2).allSatisfy(\.isNumber) {
            identifier = "imdb:\(imdbID)"
            idQueryItem = URLQueryItem(name: "imdb_id", value: imdbID)
        } else {
            return .failure(retryAfter: nil)
        }

        let key = CacheKey(identifier: identifier, season: season, episode: episode)

        if let cached = cache[key],
           cached.value != .empty || Date().timeIntervalSince(cached.fetchedAt) < 600 {
            return .success(cached.value)
        }

        if let blockedUntil, blockedUntil > Date() {
            // Recent een 429 gehad -- nog even niets nieuws proberen, maar ook niet
            // als "geen segmenten" cachen.
            return .failure(retryAfter: nil)
        }

        if let existing = inFlight[key] {
            return await existing.value
        }

        let task = Task<FetchResult, Never> { [baseURL, session] in
            var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
            var items = [idQueryItem]

            if let season, let episode {
                items.append(URLQueryItem(name: "season", value: String(season)))
                items.append(URLQueryItem(name: "episode", value: String(episode)))
            }

            if let durationSeconds, durationSeconds.isFinite,
               durationSeconds > 0, durationSeconds < Double(Int.max) / 1_000 {
                items.append(
                    URLQueryItem(name: "duration_ms", value: String(Int(durationSeconds * 1000))))
            }

            components.queryItems = items

            guard let url = components.url else { return .failure(retryAfter: nil) }

            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("Veyra/1.0", forHTTPHeaderField: "User-Agent")
            if let apiKey = AppConfiguration.introDBAPIKey, !apiKey.isEmpty {
                request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
            }

            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    #if DEBUG
                    print("[SkipSegments][TheIntroDB] error=invalidResponse")
                    #endif
                    return .failure(retryAfter: nil)
                }

                // 404 "niet gevonden" is een bevestigd, geldig antwoord van TheIntroDB
                // zelf (geen marker-data voor deze titel) -- geen storing, dus wél
                // cachebaar als leeg resultaat.
                if http.statusCode == 404 {
                    #if DEBUG
                    print("[SkipSegments][TheIntroDB] noSegments (404)")
                    #endif
                    return .success(.empty)
                }

                if http.statusCode == 429 {
                    let retry = http.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init)
                    #if DEBUG
                    print("[SkipSegments][TheIntroDB] error=rateLimited retryAfter=\(retry ?? 30)")
                    #endif
                    return .failure(retryAfter: retry ?? 30)
                }

                guard http.statusCode == 200 else {
                    #if DEBUG
                    print("[SkipSegments][TheIntroDB] error=serverError status=\(http.statusCode)")
                    #endif
                    return .failure(retryAfter: nil)
                }

                let decoded = try JSONDecoder().decode(IntroDBMediaResponse.self, from: data)
                return .success(decoded.segments)
            } catch {
                #if DEBUG
                let kind = (error as? URLError)?.code == .timedOut ? "timeout" : "invalidResponse"
                print("[SkipSegments][TheIntroDB] error=\(kind) (\(error.localizedDescription))")
                #endif
                return .failure(retryAfter: nil)
            }
        }

        inFlight[key] = task
        let outcome = await task.value
        inFlight[key] = nil

        switch outcome {
        case .success(let segments):
            cache[key] = CachedSegments(value: segments, fetchedAt: Date())
        case .failure(let retryAfter):
            if let retryAfter { blockedUntil = Date().addingTimeInterval(max(retryAfter, 1)) }
        }
        return outcome
    }
}

/// Ruwe JSON-vorm van `GET /v3/media` — zie `TheIntroDB/Api/MediaResponse.swift`
/// in de officiële Jellyfin-plugin voor het brontype waarop dit is
/// gebaseerd. Elke lijst kan meerdere segmenten per soort bevatten.
private struct IntroDBMediaResponse: Decodable {
    struct RawSegment: Decodable {
        let startMs: Double?
        let endMs: Double?

        enum CodingKeys: String, CodingKey {
            case startMs = "start_ms"
            case endMs = "end_ms"
        }
    }

    let intro: [RawSegment]?
    let recap: [RawSegment]?
    let credits: [RawSegment]?
    let preview: [RawSegment]?

    var segments: IntroDBSegments {
        IntroDBSegments(
            intros: Self.segments(from: intro),
            recaps: Self.segments(from: recap),
            creditsSegments: Self.segments(from: credits),
            previews: Self.segments(from: preview)
        )
    }

    private static func segments(from raw: [RawSegment]?) -> [IntroDBSegment] {
        (raw ?? []).compactMap { value in
            guard value.startMs != nil || value.endMs != nil else { return nil }
            return IntroDBSegment(
                start: value.startMs.map { $0 / 1_000 },
                end: value.endMs.map { $0 / 1_000 }
            )
        }
        .sorted { ($0.start ?? 0) < ($1.start ?? 0) }
    }
}
