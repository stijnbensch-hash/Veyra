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
    private var inFlight: [CacheKey: Task<IntroDBSegments, Never>] = [:]

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
            return .empty
        }

        let key = CacheKey(identifier: identifier, season: season, episode: episode)

        if let cached = cache[key],
           cached.value != .empty || Date().timeIntervalSince(cached.fetchedAt) < 600 {
            return cached.value
        }

        if let existing = inFlight[key] {
            return await existing.value
        }

        let task = Task<IntroDBSegments, Never> { [baseURL, session] in
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

            guard let url = components.url else { return .empty }

            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("Veyra/1.0", forHTTPHeaderField: "User-Agent")
            if let apiKey = AppConfiguration.introDBAPIKey, !apiKey.isEmpty {
                request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
            }

            do {
                let (data, response) = try await session.data(for: request)

                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    return .empty
                }

                let decoded = try JSONDecoder().decode(IntroDBMediaResponse.self, from: data)
                return decoded.segments
            } catch {
                return .empty
            }
        }

        inFlight[key] = task
        let result = await task.value
        inFlight[key] = nil
        cache[key] = CachedSegments(value: result, fetchedAt: Date())
        return result
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
