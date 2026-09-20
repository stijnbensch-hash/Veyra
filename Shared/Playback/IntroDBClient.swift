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
    var intro: IntroDBSegment?
    var recap: IntroDBSegment?
    var credits: IntroDBSegment?
    var preview: IntroDBSegment?

    static let empty = IntroDBSegments()
}

/// Client voor TheIntroDB (https://theintrodb.org) — een gratis, community
/// gevulde database met exacte start-/eindtijden om intro's, recaps,
/// aftitelingen en previews van films en series over te slaan. Gebruikt
/// dezelfde publieke `GET /v3/media`-endpoint als de officiële Jellyfin-
/// plugin (`api.theintrodb.org`), hier zonder API-sleutel (anonieme
/// aanvragen vallen onder hun standaard rate limit van ~30 verzoeken per
/// 10 seconden, ruim genoeg voor één opzoeking per afspeelsessie).
///
/// Matcht op TMDB-id (+ seizoen/aflevering voor series). Veyra kent geen
/// TVDB-id, dus die kant van de API wordt hier niet gebruikt.
actor IntroDBClient {
    static let shared = IntroDBClient()

    private let baseURL = URL(string: "https://api.theintrodb.org/v3/media")!
    private let session: URLSession

    private struct CacheKey: Hashable {
        let tmdbID: Int
        let season: Int?
        let episode: Int?
    }

    private var cache: [CacheKey: IntroDBSegments] = [:]
    private var inFlight: [CacheKey: Task<IntroDBSegments, Never>] = [:]

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Haalt de skip-segmenten op voor een film (season/episode = nil) of
    /// een serie-aflevering. Geeft `.empty` terug bij elke fout, ontbrekend
    /// tmdb-id, "niet gevonden" of een rate limit — zodat een aanroeper
    /// zonder foutafhandeling gewoon geen skip-knoppen toont.
    func segments(
        tmdbID: Int?, season: Int?, episode: Int?, durationSeconds: Double?
    ) async -> IntroDBSegments {
        guard let tmdbID, tmdbID > 0 else { return .empty }

        let key = CacheKey(tmdbID: tmdbID, season: season, episode: episode)

        if let cached = cache[key] { return cached }

        if let existing = inFlight[key] {
            return await existing.value
        }

        let task = Task<IntroDBSegments, Never> { [baseURL, session] in
            var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
            var items = [URLQueryItem(name: "tmdb_id", value: String(tmdbID))]

            if let season, let episode {
                items.append(URLQueryItem(name: "season", value: String(season)))
                items.append(URLQueryItem(name: "episode", value: String(episode)))
            }

            if let durationSeconds, durationSeconds > 0 {
                items.append(
                    URLQueryItem(name: "duration_ms", value: String(Int(durationSeconds * 1000))))
            }

            components.queryItems = items

            guard let url = components.url else { return .empty }

            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("Veyra/1.0", forHTTPHeaderField: "User-Agent")

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
        cache[key] = result
        return result
    }
}

/// Ruwe JSON-vorm van `GET /v3/media` — zie `TheIntroDB/Api/MediaResponse.swift`
/// in de officiële Jellyfin-plugin voor het brontype waarop dit is
/// gebaseerd. Elke lijst bevat 0 of meer segmenten; Veyra gebruikt alleen
/// het eerste (langste/meest waarschijnlijke) segment per soort.
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
            intro: Self.segment(from: intro),
            recap: Self.segment(from: recap),
            credits: Self.segment(from: credits),
            preview: Self.segment(from: preview)
        )
    }

    private static func segment(from raw: [RawSegment]?) -> IntroDBSegment? {
        guard let first = raw?.first, first.startMs != nil || first.endMs != nil else { return nil }
        return IntroDBSegment(
            start: first.startMs.map { $0 / 1000 },
            end: first.endMs.map { $0 / 1000 }
        )
    }
}
