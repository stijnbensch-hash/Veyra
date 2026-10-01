import Foundation

/// Rauwe shape van SkipDB's `GET /api/segments`-response (https://skipdb.tv/docs).
/// `segments` heeft altijd exact de vier sleutels; een ontbrekend segment is
/// gewoon `null`, geen fout.
private struct SkipDBSegmentsResponse: Decodable {
    struct RawSegment: Decodable {
        let startMs: Double
        let endMs: Double
        let confidence: Double?
        /// SkipDB's eigen duration-compatibiliteitsoordeel voor de
        /// meegegeven `duration` (spec §45/100, "wrong duration"):
        /// "exact" / "shifted" / "out-of-range" (zie `SkipDBClient.map`).
        let match: String?
        /// True wanneer SkipDB zelf al een kleine, provider-berekende
        /// correctie op de timestamps heeft toegepast -- geen eigen blinde
        /// offset (spec §46: alleen gebruiken als de provider dit expliciet
        /// ondersteunt).
        let adjusted: Bool?

        enum CodingKeys: String, CodingKey {
            case startMs = "start_ms"
            case endMs = "end_ms"
            case confidence
            case match
            case adjusted
        }
    }

    struct Segments: Decodable {
        let intro: RawSegment?
        let recap: RawSegment?
        let outro: RawSegment?
        let preview: RawSegment?
    }

    let segments: Segments
}

/// Client voor SkipDB (https://skipdb.tv) -- een open, crowdsourced database
/// met intro-/recap-/outro-/preview-tijden, met optionele duration-aware
/// matching (spec §17-19: verschillende releases van dezelfde aflevering
/// kunnen een andere duur hebben, dus geen perfect gelijke timestamps).
/// Matcht uitsluitend op IMDb-id; TMDB wordt door deze API niet ondersteund
/// (spec §10: "provider adapter bepaalt welke IDs hij ondersteunt").
///
/// Zelfde "error ≠ empty"-principe als `IntroDBClient` (spec §37/Fase 4):
/// een storing (timeout/429/5xx) wordt nooit als "geen segmenten" behandeld
/// -- `FetchResult.failure` maakt dat onderscheid expliciet voor de
/// aanroepende provider.
actor SkipDBClient {
    static let shared = SkipDBClient()

    private let baseURL = URL(string: "https://api.skipdb.tv/api/segments")!
    private let session: URLSession

    enum FetchResult {
        case success([VeyraSkipSegment])
        case failure(retryAfter: TimeInterval?)
    }

    /// Na een 429 even helemaal geen nieuwe requests sturen, i.p.v. iedere
    /// aanroep opnieuw te laten falen op de server (spec §80: "Geen
    /// onmiddellijke retry-loop").
    private var blockedUntil: Date?

    init(session: URLSession = .shared) {
        self.session = session
    }

    func lookup(
        imdbID: String, season: Int?, episode: Int?, durationSeconds: Double?
    ) async -> FetchResult {
        if let blockedUntil, blockedUntil > Date() {
            return .failure(retryAfter: nil)
        }

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        var items = [URLQueryItem(name: "imdb_id", value: imdbID)]
        if let season { items.append(URLQueryItem(name: "season", value: String(season))) }
        if let episode { items.append(URLQueryItem(name: "episode", value: String(episode))) }
        if let durationSeconds, durationSeconds.isFinite, durationSeconds > 0 {
            // SkipDB raadt duration expliciet aan voor accuratere matching
            // tussen releases met een afwijkende duur (spec §19).
            items.append(URLQueryItem(name: "duration", value: String(Int(durationSeconds))))
        }
        components.queryItems = items

        guard let url = components.url else { return .failure(retryAfter: nil) }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Veyra/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                #if DEBUG
                print("[SkipSegments][SkipDB] error=invalidResponse")
                #endif
                return .failure(retryAfter: nil)
            }

            // Een titel zonder enige bijdrage is een bevestigd leeg antwoord,
            // geen storing.
            if http.statusCode == 404 {
                #if DEBUG
                print("[SkipSegments][SkipDB] noSegments (404)")
                #endif
                return .success([])
            }

            if http.statusCode == 429 {
                let retry = http.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init)
                blockedUntil = Date().addingTimeInterval(max(retry ?? 30, 1))
                #if DEBUG
                print("[SkipSegments][SkipDB] error=rateLimited retryAfter=\(retry ?? 30)")
                #endif
                return .failure(retryAfter: retry ?? 30)
            }

            guard http.statusCode == 200 else {
                #if DEBUG
                print("[SkipSegments][SkipDB] error=serverError status=\(http.statusCode)")
                #endif
                return .failure(retryAfter: nil)
            }

            let decoded = try JSONDecoder().decode(SkipDBSegmentsResponse.self, from: data)
            return .success(Self.map(decoded.segments))
        } catch {
            #if DEBUG
            let kind = (error as? URLError)?.code == .timedOut ? "timeout" : "invalidResponse"
            print("[SkipSegments][SkipDB] error=\(kind) (\(error.localizedDescription))")
            #endif
            return .failure(retryAfter: nil)
        }
    }

    private static func map(_ segments: SkipDBSegmentsResponse.Segments) -> [VeyraSkipSegment] {
        var result: [VeyraSkipSegment] = []
        func append(_ raw: SkipDBSegmentsResponse.RawSegment?, type: VeyraSkipSegmentType) {
            guard let raw else { return }
            // "0-0" is SkipDB's sentinel voor "bevestigd geen segment van dit
            // type" (min. segmentlengte is 5s) -- geen geldig segment, niet tonen.
            guard raw.endMs > raw.startMs else { return }
            // Duration-compatibiliteit (spec §45/100, "wrong duration" ->
            // verlaag confidence of reject): "out-of-range" is SkipDB's
            // eigen oordeel dat geen release bij de meegegeven duration
            // past -- niet bruikbaar. Dit is geen eigen gokwerk van Veyra,
            // SkipDB berekent dit zelf serverside op basis van de
            // meegegeven `duration` (spec §46).
            guard raw.match != "out-of-range" else { return }
            let start = raw.startMs / 1000.0
            let end = raw.endMs / 1000.0
            // SkipDB levert een eigen confidence-score (0-1); gebruik die
            // indien aanwezig, anders een redelijk standaard (spec §52:
            // "external marker + matching duration -> high"). Een "shifted"
            // match (SkipDB paste zelf al een kleine correctie toe) is
            // minder zeker dan een exacte match -- lichte reductie, geen
            // reject (spec §45: "verlaag confidence OF reject", niet beide).
            let baseConfidence = raw.confidence ?? 0.75
            let confidence = raw.match == "shifted" ? baseConfidence * 0.85 : baseConfidence
            result.append(VeyraSkipSegment(
                id: "skipdb-\(type.rawValue)-\(Int(start))-\(Int(end))",
                type: type,
                start: start,
                end: end,
                source: .skipDB,
                confidence: confidence
            ))
        }
        append(segments.intro, type: .intro)
        append(segments.recap, type: .recap)
        append(segments.outro, type: .credits)
        append(segments.preview, type: .preview)
        return result
    }
}
