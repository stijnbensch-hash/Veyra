// VeyraBentoTrakt.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// Gegevenslaag voor de home-secties "Verder kijken" en "Binnenkort", gevoed door Trakt.
// (Vereiste HeroMoment/HeroContent-koppeling met VeyraBentoHeroModel.swift is opgeruimd, was ongebruikt.)
//
// Trakt-endpoints (allemaal OAuth):
//   Verder kijken
//     GET  /sync/playback?extended=full            onderbroken films/afleveringen, met voortgang (%)
//     GET  /sync/watched/shows?extended=noseasons  recent bekeken series
//     GET  /shows/{id}/progress/watched            next_episode = "volgende aflevering"
//     DELETE /sync/playback/{id}                   uit Verder kijken halen
//   Binnenkort
//     GET  /calendars/my/shows/{start}/{days}?extended=full   afleveringen van series die je volgt
//     GET  /calendars/my/movies/{start}/{days}                films uit je watchlist/collectie
//
// Trakt levert geen afbeeldingen: ArtworkProviding koppelt via het TMDB-id aan jullie TMDBClient.
// Trakt-limiet: 1000 GET-requests per 5 minuten. Up-next doet daarom maximaal `upNextLimit` extra calls.
//
// Inpassen: TraktHomeAPI gebruikt hier een eigen minimale client. Heeft Veyra al een TraktClient
// met token-verversing, laat die dan `TraktTokenProviding` implementeren of pas `get(_:query:)` aan.

import Foundation
import Observation

// MARK: - Domeinmodellen

nonisolated enum MediaKind: String, Sendable, Codable { case movie, episode }

/// Trakt geeft voor afleveringen zonder eigen titel vaak een kale placeholder terug
/// ("Episode 10", "Aflevering 10") i.p.v. `nil` -- dat dupliceert wat de episodecode
/// ("S11E10") al zegt, dus zo'n titel telt hier als "geen titel".
nonisolated private func isGenericEpisodeTitle(_ title: String?, code: String?) -> Bool {
    guard let title else { return false }
    let trimmed = title.trimmingCharacters(in: .whitespaces)
    guard let number = code?.split(separator: "E").last else {
        return trimmed.range(of: #"^(Episode|Aflevering)\s*\d+$"#, options: [.regularExpression, .caseInsensitive]) != nil
    }
    return trimmed.range(of: #"^(Episode|Aflevering)\s*0*\#(number)$"#, options: [.regularExpression, .caseInsensitive]) != nil
}

nonisolated struct Artwork: Sendable, Equatable {
    var backdrop: URL?
    var logo: URL?
    var banner: URL? = nil
}

nonisolated struct ContinueItem: Identifiable, Hashable, Sendable, Codable {
    let id: String                 // "pb-123" of "next-<showTraktID>-S2E5"
    let playbackID: Int?           // nodig voor DELETE /sync/playback/{id}
    let kind: MediaKind
    let title: String              // serie- of filmtitel
    let year: Int?
    let episodeCode: String?       // "S2E4"
    let episodeTitle: String?
    let progress: Double           // 0...1; 0 bij "volgende aflevering"
    let remainingMinutes: Int?
    let tmdbID: Int?
    let showTraktID: Int?
    let lastWatched: Date
    let isUpNext: Bool
    var backdropURL: URL? = nil
    var logoURL: URL? = nil
    var bannerURL: URL? = nil
    var watchedEpisodes: Int? = nil      // afleveringen gezien (Trakt-voortgang)
    var airedEpisodes: Int? = nil        // afleveringen uitgezonden

    var episodesLeft: Int? {
        guard let watched = watchedEpisodes, let aired = airedEpisodes else { return nil }
        return max(aired - watched, 0)
    }

    var subtitle: String? {
        switch (episodeCode, episodeTitle) {
        case let (c?, t?) where !isGenericEpisodeTitle(t, code: c): return "\(c) · \(t)"
        case let (c?, _): return c
        default: return year.map(String.init)
        }
    }

    /// "S2E4 · nog 23 min · 12 gezien · 8 te gaan" / "Film · nog 71 min"
    var metaText: String {
        var parts = [kind == .movie ? "Film" : (episodeCode ?? "Aflevering")]
        if !isUpNext {
            if let r = remainingMinutes { parts.append("nog \(r) min") } else { parts.append("\(Int((progress * 100).rounded()))%") }
        }
        if let watched = watchedEpisodes, let left = episodesLeft {
            parts.append("\(watched) gezien")
            parts.append("\(left) te gaan")
        }
        return parts.joined(separator: " · ")
    }

    /// "S2E4 · nog 23 min" (zonder aantallen)
    var baseMetaText: String {
        var parts = [kind == .movie ? "Film" : (episodeCode ?? "Aflevering")]
        if !isUpNext {
            if let r = remainingMinutes { parts.append("nog \(r) min") } else { parts.append("\(Int((progress * 100).rounded()))%") }
        }
        return parts.joined(separator: " · ")
    }

    /// "12 gezien · 8 te gaan"
    var countsText: String? {
        guard let watched = watchedEpisodes, let left = episodesLeft else { return nil }
        return "\(watched) gezien · \(left) te gaan"
    }

    /// Korte variant voor kleine kaartjes: "S2E4 · 8 te gaan".
    var shortMetaText: String {
        var parts = [kind == .movie ? "Film" : (episodeCode ?? "Aflevering")]
        if let left = episodesLeft { parts.append("\(left) te gaan") }
        else if !isUpNext, let r = remainingMinutes { parts.append("nog \(r) min") }
        return parts.joined(separator: " · ")
    }
}

nonisolated struct UpcomingItem: Identifiable, Equatable, Sendable, Codable {
    let id: String
    let kind: MediaKind
    let title: String
    let episodeCode: String?
    let episodeTitle: String?
    let airDate: Date
    let isDateOnly: Bool           // films: Trakt geeft alleen een datum, geen tijdstip
    let runtimeMinutes: Int?
    let tmdbID: Int?
    let showTraktID: Int?
    var backdropURL: URL? = nil
    var logoURL: URL? = nil

    var subtitle: String? {
        switch (episodeCode, episodeTitle) {
        case let (c?, t?) where !isGenericEpisodeTitle(t, code: c): return "\(c) · \(t)"
        case let (c?, _): return c
        default: return nil
        }
    }
}

// MARK: - Formattering (nl)

nonisolated enum VeyraHomeFormat {
    static let locale = Locale(identifier: "nl_BE")

    /// "Vandaag 20:00" · "Morgen 20:00" · "vr 25 sep"
    static func when(_ date: Date, now: Date, dateOnly: Bool = false, calendar: Calendar = .current) -> String {
        let time = date.formatted(.dateTime.hour().minute().locale(locale))
        if calendar.isDate(date, inSameDayAs: now) { return dateOnly ? "Vandaag" : "Vandaag \(time)" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) {
            return dateOnly ? "Morgen" : "Morgen \(time)"
        }
        let day = date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(locale))
        return dateOnly ? day : "\(day) · \(time)"
    }

    /// "2u 14m" · "1 dag 3u" · "3 dagen" · "12 min"
    static func countdown(to date: Date, now: Date) -> String {
        let minutes = Int(max(0, date.timeIntervalSince(now)) / 60)
        if minutes >= 2 * 1440 { return "\(minutes / 1440) dagen" }
        if minutes >= 1440 { return "1 dag \((minutes % 1440) / 60)u" }
        if minutes >= 60 { return "\(minutes / 60)u \(minutes % 60)m" }
        return "\(max(minutes, 1)) min"
    }

    /// Voortgang van de aftel-lijn: vult zich over de laatste 24 uur voor de release.
    static func countdownProgress(to date: Date, now: Date) -> Double {
        let remaining = max(0, date.timeIntervalSince(now))
        return 1 - min(remaining / 86_400, 1)
    }
}

// MARK: - Bronnen

nonisolated protocol TraktTokenProviding: Sendable {
    func accessToken() async throws -> String
}

nonisolated protocol ArtworkProviding: Sendable {
    /// Backdrop + clearlogo via TMDB (`/images`, taalkeuze NL → EN → taalloos: zie pickClearlogoURL).
    func artwork(for kind: MediaKind, tmdbID: Int) async -> Artwork?
}

nonisolated protocol TraktHomeProviding: Sendable {
    func continueWatching(limit: Int) async throws -> [ContinueItem]
    func upcoming(days: Int) async throws -> [UpcomingItem]
    func removePlayback(id: Int) async throws
}

nonisolated enum TraktHomeError: Error, LocalizedError {
    case invalidResponse, unauthorized, notLinked, rateLimited(retryAfter: TimeInterval?), http(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Ongeldig antwoord van Trakt."
        case .unauthorized: return "Trakt-sessie verlopen. Log opnieuw in."
        case .notLinked: return "Trakt is niet gekoppeld. Koppel je account via Instellingen > Account."
        case .rateLimited: return "Trakt-limiet bereikt. Probeer zo opnieuw."
        case .http(let code): return "Trakt gaf fout \(code)."
        }
    }
}

// MARK: - Trakt DTO's (snake_case -> camelCase via keyDecodingStrategy)

nonisolated struct TraktHomeIDs: Decodable, Sendable {
    let trakt: Int?
    let slug: String?
    let tmdb: Int?
    let imdb: String?
}
nonisolated struct TraktMovieDTO: Decodable, Sendable {
    let title: String
    let year: Int?
    let ids: TraktHomeIDs
    let runtime: Int?
}
nonisolated struct TraktShowDTO: Decodable, Sendable {
    let title: String
    let year: Int?
    let ids: TraktHomeIDs
    let runtime: Int?
}
nonisolated struct TraktEpisodeDTO: Decodable, Sendable {
    let season: Int
    let number: Int
    let title: String?
    let ids: TraktHomeIDs?
    let runtime: Int?
}
nonisolated struct TraktPlaybackDTO: Decodable, Sendable {
    let id: Int
    let progress: Double
    let pausedAt: Date
    let type: String
    let movie: TraktMovieDTO?
    let episode: TraktEpisodeDTO?
    let show: TraktShowDTO?
}
nonisolated struct TraktWatchedShowDTO: Decodable, Sendable {
    let lastWatchedAt: Date
    let show: TraktShowDTO
}
nonisolated struct TraktShowProgressDTO: Decodable, Sendable {
    let aired: Int?
    let completed: Int?
    let nextEpisode: TraktEpisodeDTO?
}
nonisolated struct TraktCalendarShowDTO: Decodable, Sendable {
    let firstAired: Date
    let episode: TraktEpisodeDTO
    let show: TraktShowDTO
}
nonisolated struct TraktCalendarMovieDTO: Decodable, Sendable {
    let released: String          // "2026-09-25"
    let movie: TraktMovieDTO
}

// MARK: - Live Trakt-implementatie

/// Deelt voortgangsresultaten (15 min) en pauzeert extra calls na een 429, zodat Home de Trakt-limiet niet steeds opnieuw raakt.
extension Notification.Name {
    /// Trakt-kijkgeschiedenis is net gewijzigd (bv. aflevering afgekeken): Home moet "Verder kijken" opnieuw ophalen.
    static let veyraTraktHistoryDidChange = Notification.Name("veyra.trakt.historyDidChange")
}

nonisolated final class TraktHomeThrottle: @unchecked Sendable {
    static let shared = TraktHomeThrottle()
    private let lock = NSLock()
    private var progress: [Int: (at: Date, value: TraktShowProgressDTO)] = [:]
    private var blockedUntil = Date.distantPast

    var isBlocked: Bool {
        lock.lock(); defer { lock.unlock() }
        return Date() < blockedUntil
    }

    func cached(_ showID: Int) -> TraktShowProgressDTO? {
        lock.lock(); defer { lock.unlock() }
        guard let hit = progress[showID], Date().timeIntervalSince(hit.at) < 900 else { return nil }
        return hit.value
    }

    func store(_ value: TraktShowProgressDTO, for showID: Int) {
        lock.lock(); defer { lock.unlock() }
        progress[showID] = (Date(), value)
    }

    /// Gooit de gecachete voortgang weg (na een scrobble/afgekeken aflevering), anders blijft
    /// "Verder kijken" tot 15 minuten de net bekeken aflevering als volgende tonen.
    func invalidate() {
        lock.lock(); defer { lock.unlock() }
        progress.removeAll()
    }

    func block(for seconds: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        blockedUntil = Date().addingTimeInterval(max(seconds, 20))
    }
}

nonisolated final class TraktHomeAPI: TraktHomeProviding {
    private let clientID: String
    private let tokens: any TraktTokenProviding
    private let session: URLSession
    private let base = URL(string: "https://api.trakt.tv")!
    private let upNextLimit: Int

    init(clientID: String,
         tokens: any TraktTokenProviding,
         session: URLSession = .shared,
         upNextLimit: Int = 200) {
        self.clientID = clientID
        self.tokens = tokens
        self.session = session
        self.upNextLimit = upNextLimit
    }

    // MARK: Verder kijken

    func continueWatching(limit: Int) async throws -> [ContinueItem] {
        try await baseContinueWatching(limit: limit)
    }

    /// Voortgang van één serie: uit de cache, anders van Trakt (niet tijdens een limiet-pauze).
    private func showProgress(_ sid: Int) async -> TraktShowProgressDTO? {
        let throttle = TraktHomeThrottle.shared
        if let hit = throttle.cached(sid) { return hit }
        if throttle.isBlocked { return nil }
        do {
            let progress: TraktShowProgressDTO = try await get(
                "shows/\(sid)/progress/watched",
                query: [.init(name: "hidden", value: "false"), .init(name: "specials", value: "false")])
            throttle.store(progress, for: sid)
            return progress
        } catch TraktHomeError.rateLimited(let after) {
            throttle.block(for: after ?? 30)
            return nil
        } catch {
            return nil
        }
    }

    /// Vult per serie in hoeveel afleveringen gezien zijn en hoeveel er nog resten (Trakt `progress/watched`).
    private func withEpisodeCounts(_ items: [ContinueItem]) async -> [ContinueItem] {
        var requestedShows = Set<Int>()
        let wanted = items.compactMap { item -> Int? in
            guard item.kind == .episode, item.airedEpisodes == nil,
                  let id = item.showTraktID, requestedShows.insert(id).inserted else { return nil }
            return id
        }
        var counts: [Int: (Int, Int)] = [:]
        var index = 0
        while index < wanted.count, !TraktHomeThrottle.shared.isBlocked {
            let chunk = Array(wanted[index..<min(index + 6, wanted.count)])
            index += 6
            let part = await withTaskGroup(of: (Int, Int, Int)?.self) { group in
                for sid in chunk {
                    group.addTask { [self] in
                        guard let progress = await showProgress(sid),
                              let aired = progress.aired, let completed = progress.completed else { return nil }
                        return (sid, completed, aired)
                    }
                }
                var found: [(Int, Int, Int)] = []
                for await result in group { if let result { found.append(result) } }
                return found
            }
            for (id, completed, aired) in part { counts[id] = (completed, aired) }
        }
        return items.map { item in
            guard let id = item.showTraktID,
                  let (completed, aired) = counts[id] else { return item }
            var copy = item
            copy.watchedEpisodes = completed
            copy.airedEpisodes = aired
            return copy
        }
    }

    private func baseContinueWatching(limit: Int) async throws -> [ContinueItem] {
        let playback: [TraktPlaybackDTO] = try await get("sync/playback", query: [.init(name: "extended", value: "full")])

        // Onderbroken items, nieuwste eerst; één checkpoint per serie.
        //
        // STAP 1 Trakt-performance-refactor: deze functie deed hier voorheen ZELF nog
        // eens tientallen tot ~200 losse `shows/{id}/progress/watched`-aanroepen (plus een
        // aparte, nogmaals gepagineerde `sync/watched/shows`-call) om te bepalen welke
        // checkpoints al voltooid zijn en welke series een "volgende aflevering" hebben --
        // volledig los van, en overlappend met, de normale `TraktStore`-refresh die diezelfde
        // informatie al in één bulkaanroep (`sync/progress/up_next`) ophaalt. Die aanvulling
        // gebeurt nu lokaal, zonder extra netwerkverkeer, in
        // `VeyraHomeViewModel.mergedWithLocalUpNext(_:limit:)` met `TraktStore.shared.upNext`.
        var items: [ContinueItem] = []
        let checkpointScanLimit = max(limit * 4, 100)
        for p in playback.sorted(by: { $0.pausedAt > $1.pausedAt }).prefix(checkpointScanLimit) {
            let fraction = min(max(p.progress / 100, 0), 1)
            switch p.type {
            case "movie":
                guard let m = p.movie else { continue }
                items.append(ContinueItem(
                    id: "pb-\(p.id)", playbackID: p.id, kind: .movie, title: m.title, year: m.year,
                    episodeCode: nil, episodeTitle: nil, progress: fraction,
                    remainingMinutes: m.runtime.map { Int((Double($0) * (1 - fraction)).rounded()) },
                    tmdbID: m.ids.tmdb, showTraktID: nil, lastWatched: p.pausedAt, isUpNext: false))
            case "episode":
                guard let e = p.episode, let s = p.show else { continue }
                let runtime = e.runtime ?? s.runtime
                items.append(ContinueItem(
                    id: "pb-\(p.id)", playbackID: p.id, kind: .episode, title: s.title, year: s.year,
                    episodeCode: Self.code(e), episodeTitle: e.title, progress: fraction,
                    remainingMinutes: runtime.map { Int((Double($0) * (1 - fraction)).rounded()) },
                    tmdbID: s.ids.tmdb, showTraktID: s.ids.trakt, lastWatched: p.pausedAt, isUpNext: false))
            default: continue
            }
        }
        var seenShows = Set<Int>()
        items = items.filter { item in
            guard item.kind == .episode, let id = item.showTraktID else { return true }
            return seenShows.insert(id).inserted
        }
        return Array(items.prefix(limit))
    }

    func removePlayback(id: Int) async throws {
        _ = try await send("sync/playback/\(id)", method: "DELETE", query: [])
    }

    // MARK: Binnenkort

    func upcoming(days: Int) async throws -> [UpcomingItem] {
        let start = Self.dayString(Date())
        async let shows: [TraktCalendarShowDTO] = get("calendars/my/shows/\(start)/\(days)", query: [.init(name: "extended", value: "full")])
        async let movies: [TraktCalendarMovieDTO] = get("calendars/my/movies/\(start)/\(days)", query: [])

        let now = Date()
        var out: [UpcomingItem] = []
        for entry in try await shows where entry.firstAired > now && entry.episode.season > 0 {
            let code = Self.code(entry.episode)
            out.append(UpcomingItem(
                id: "cal-\(entry.show.ids.trakt ?? 0)-\(code)", kind: .episode, title: entry.show.title,
                episodeCode: code, episodeTitle: entry.episode.title, airDate: entry.firstAired, isDateOnly: false,
                runtimeMinutes: entry.episode.runtime ?? entry.show.runtime,
                tmdbID: entry.show.ids.tmdb, showTraktID: entry.show.ids.trakt))
        }
        for entry in (try? await movies) ?? [] {
            guard let date = Self.localDay(entry.released), date >= Calendar.current.startOfDay(for: now) else { continue }
            out.append(UpcomingItem(
                id: "cal-m-\(entry.movie.ids.trakt ?? 0)", kind: .movie, title: entry.movie.title,
                episodeCode: nil, episodeTitle: nil, airDate: date, isDateOnly: true,
                runtimeMinutes: entry.movie.runtime, tmdbID: entry.movie.ids.tmdb, showTraktID: nil))
        }
        return out.sorted { $0.airDate < $1.airDate }
    }

    // MARK: HTTP

    private func get<T: Decodable & Sendable>(_ path: String, query: [URLQueryItem]) async throws -> T {
        let data = try await send(path, method: "GET", query: query)
        return try Self.decoder().decode(T.self, from: data)
    }

    /// Trakt geeft af en toe een transiënte 500/502/503 terug zonder dat er
    /// iets mis is met het verzoek zelf -- vandaar één korte retry vóór we de
    /// fout laten zien. Geen retry op 4xx: dat is een verzoek-/auth-probleem
    /// dat opnieuw proberen toch niet oplost.
    ///
    /// Bewust maar één korte retry, niet drie oplopend tot 5s: `send()` wordt
    /// ook gebruikt door de per-serie `progress/watched`-aanroepen die
    /// "Verder kijken" doet (tot ~40, in groepjes van 6). Bij een bredere
    /// Trakt-storing telden 3 retries per mislukte aanroep op tot tientallen
    /// seconden extra wachttijd — "Verder kijken"/"Binnenkort" moeten meteen
    /// bij het openen van de app laden, ook als Trakt net hapert.
    private static let serverErrorRetryDelays: [UInt64] = [300_000_000] // ns: 0.3s

    private func send(_ path: String, method: String, query: [URLQueryItem]) async throws -> Data {
        var comps = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { comps.queryItems = query }
        var request = URLRequest(url: comps.url!)
        request.httpMethod = method
        // Zonder expliciete timeout viel dit terug op de systeemdefault (~60s) i.p.v.
        // de 30s die `TraktClient` al gebruikt -- audit P2: een trage/hangende aanroep
        // hield Home's "Verder kijken"/"Binnenkort" dus twee keer zo lang vast.
        request.timeoutInterval = 30
        let accessToken = try await tokens.accessToken()
        TraktRequestHeaders.apply(to: &request, clientID: clientID, accessToken: accessToken)

        var attempt = 0
        while true {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw TraktHomeError.invalidResponse }
            switch http.statusCode {
            case 200..<300:
                return data
            case 401:
                throw TraktHomeError.unauthorized
            case 429:
                throw TraktHomeError.rateLimited(retryAfter: http.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init))
            case 500..<600 where attempt < Self.serverErrorRetryDelays.count:
                try? await Task.sleep(nanoseconds: Self.serverErrorRetryDelays[attempt])
                attempt += 1
            default:
                throw TraktHomeError.http(http.statusCode)
            }
        }
    }

    // MARK: Hulpjes

    private static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .custom { decoder in
            let s = try decoder.singleValueContainer().decode(String.self)
            if let date = try? Date(s, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)) { return date }
            if let date = try? Date(s, strategy: Date.ISO8601FormatStyle()) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Ongeldige datum: \(s)"))
        }
        return d
    }

    private static func code(_ e: TraktEpisodeDTO) -> String { String(format: "S%02dE%02d", e.season, e.number) }

    private static func dayString(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 1970, c.month ?? 1, c.day ?? 1)
    }

    /// "2026-09-25" -> 25 sep 00:00 in de lokale tijdzone.
    private static func localDay(_ string: String) -> Date? {
        let p = string.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: p[0], month: p[1], day: p[2]))
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class VeyraHomeViewModel {
    enum Phase: Equatable { case idle, loading, loaded, failed(String) }

    private(set) var continueItems: [ContinueItem] = []
    private(set) var upcoming: [UpcomingItem] = []
    private(set) var phase: Phase = .idle
    private(set) var reminderIDs: Set<String> = []
    /// Reden waarom Verder kijken / Binnenkort leeg zijn (Trakt niet gekoppeld, sessie verlopen, netwerkfout).
    private(set) var notice: String?

    @ObservationIgnored private let provider: any TraktHomeProviding
    @ObservationIgnored private let artwork: (any ArtworkProviding)?
    @ObservationIgnored private var artworkCache: [Int: Artwork] = [:]
    @ObservationIgnored private var bannerAttempts: [Int: Int] = [:]
    @ObservationIgnored private var cachedWithFanartKey = false

    init(provider: any TraktHomeProviding, artwork: (any ArtworkProviding)? = nil, reminders: Set<String> = []) {
        self.provider = provider
        self.artwork = artwork
        self.reminderIDs = reminders
        // Vorige sessie's resultaat meteen tonen (incl. eerder opgehaalde beeld-URL's) zodat
        // "Verder kijken"/"Binnenkort" al op het scherm staan voordat `load()` klaar is --
        // wordt zo dadelijk gewoon overschreven door de verse Trakt-data.
        if let cached = Self.loadCache() {
            continueItems = cached.continueItems
            upcoming = cached.upcoming
        }
        // Opruimen: eerdere (inmiddels verwijderde) versie schreef deze cache nog naar
        // UserDefaults, waar een te grote waarde de app kon laten crashen ("byte count limit
        // reached"). Eenmalig verwijderen zodat een reeds opgeslagen te-grote waarde niet blijft
        // hangen.
        UserDefaults.standard.removeObject(forKey: "VeyraHomeViewModel.cache.v1")
    }

    private struct HomeCache: Codable {
        let continueItems: [ContinueItem]
        let upcoming: [UpcomingItem]
    }

    /// Bewust een los bestand in Caches, geen UserDefaults: NSUserDefaults/CFPreferences
    /// weigert waarden vanaf ~1MB ("byte count limit reached") en crasht de app daarop --
    /// gezien "Binnenkort" een ongelimiteerd aantal Trakt-items kan bevatten (elk met eigen
    /// backdrop-/logo-URL's) is die grens met wat pech gewoon haalbaar. Een los bestand kent
    /// die limiet niet.
    private static var cacheFileURL: URL? {
        guard let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        return dir.appendingPathComponent("veyra-home-cache.json")
    }

    private static func loadCache() -> HomeCache? {
        guard let url = cacheFileURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(HomeCache.self, from: data)
    }

    private func saveCache() {
        guard let url = Self.cacheFileURL else { return }
        // Extra begrenzing (naast de eigen `continueWatchingLimit`-knip hierboven): "Binnenkort"
        // kan in theorie fors uitlopen; hier hard afgekapt zodat het cachebestand sowieso klein
        // en snel te lezen/schrijven blijft, ongeacht hoeveel Trakt teruggeeft.
        let payload = HomeCache(continueItems: continueItems, upcoming: Array(upcoming.prefix(60)))
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: url, options: .atomic)
    }

    nonisolated private static func capture<T: Sendable>(_ work: @Sendable () async throws -> T) async -> Result<T, Error> {
        do { return .success(try await work()) } catch { return .failure(error) }
    }

    /// "Home \u2192 Verder kijken en Binnenkort \u2192 Aantal tegels" begrenst hoeveel
    /// "Verder kijken"-kaarten getoond worden, meest recente behouden. Rechtstreeks uit
    /// UserDefaults gelezen (i.p.v. @AppStorage, dat enkel in Views werkt); 10 als terugval
    /// zolang de instelling nooit is opgeslagen (UserDefaults.integer geeft dan 0 terug).
    private static var continueWatchingLimit: Int {
        let stored = UserDefaults.standard.integer(forKey: GeneralSettingsDefaults.continueWatchingLimitKey)
        return stored > 0 ? min(stored, 50) : 10
    }

    func load() async {
        phase = .loading
        let provider = self.provider
        let fetchLimit = Self.continueWatchingLimit
        async let cont = Self.capture { try await provider.continueWatching(limit: fetchLimit) }
        async let soon = Self.capture { try await provider.upcoming(days: 14) }
        let (c, u) = await (cont, soon)

        if case .success(let items) = c {
            // De provider levert alleen de onderbroken checkpoints (uit `sync/playback`).
            // Voltooide checkpoints wegfilteren en series zonder actief hervatpunt aanvullen
            // met hun volgende aflevering gebeurt hier lokaal, uit `TraktStore.shared.upNext`
            // (al opgehaald via de gewone Trakt-refresh) -- zie `mergedWithLocalUpNext`.
            continueItems = mergedWithLocalUpNext(items, limit: Self.continueWatchingLimit)
        }
        if case .success(let items) = u { upcoming = items }
        // Nieuw opgehaalde items hebben nog geen beeld: hergebruik wat al eerder is opgehaald.
        for (id, art) in artworkCache { apply(art, to: id) }

        switch (c, u) {
        case (.failure(let e), .failure): phase = .failed(e.localizedDescription)
        default: phase = .loaded
        }
        // Toon de foutmelding alleen als er voor die sectie niets te laten zien is -- anders
        // blokkeert een mislukte "Binnenkort"-call (bv. een tijdelijke Trakt 500) onterecht het
        // hele scherm terwijl "Verder kijken" wel gewoon geladen is (en omgekeerd).
        if case .failure(let e) = c, continueItems.isEmpty { notice = e.localizedDescription }
        else if case .failure(let e) = u, upcoming.isEmpty { notice = e.localizedDescription }
        else { notice = nil }
        saveCache()
        await enrichArtwork()
        saveCache()
    }

    /// Vult de door de provider geleverde "Verder kijken"-checkpoints lokaal aan,
    /// zonder extra Trakt-aanroepen: filtert checkpoints die volgens Trakt's eigen
    /// voortgangstelling al voltooid zijn, en vult series zonder actief hervatpunt aan
    /// met hun volgende aflevering -- beide uit `TraktStore.shared.upNext`
    /// (`sync/progress/up_next`, één bulkaanroep die `TraktStore` toch al bij elke
    /// gewone refresh doet). Stap 1 van de Trakt-performance-refactor: zie
    /// `TraktHomeAPI.baseContinueWatching` voor de volledige toelichting.
    private func mergedWithLocalUpNext(_ items: [ContinueItem], limit: Int) -> [ContinueItem] {
        let upNext = TraktStore.shared.upNext
        guard !upNext.isEmpty else { return items }

        var progressByShow: [Int: TraktShowProgress] = [:]
        for entry in upNext {
            guard let sid = entry.show.ids.trakt else { continue }
            progressByShow[sid] = entry.progress
        }

        // 1. Checkpoints die ondertussen al volledig uitgekeken zijn, wegfilteren.
        var merged: [ContinueItem] = items.compactMap { item in
            guard item.kind == .episode, let sid = item.showTraktID,
                  let progress = progressByShow[sid] else { return item }
            var copy = item
            copy.watchedEpisodes = progress.completed
            copy.airedEpisodes = progress.aired
            return (copy.episodesLeft ?? 1) > 0 ? copy : nil
        }

        guard merged.count < limit else { return Array(merged.prefix(limit)) }
        let keptShowIDs = Set(merged.compactMap(\.showTraktID))

        // 2. Series zonder actief hervatpunt aanvullen met hun volgende aflevering.
        let additions: [ContinueItem] = upNext.compactMap { entry in
            guard let sid = entry.show.ids.trakt, !keptShowIDs.contains(sid),
                  let next = entry.progress.nextEpisode,
                  entry.progress.aired - entry.progress.completed > 0
            else { return nil }
            let code = String(format: "S%02dE%02d", next.season ?? 0, next.number ?? 0)
            var item = ContinueItem(
                id: "next-\(sid)-\(code)", playbackID: nil, kind: .episode,
                title: entry.show.title ?? "Serie", year: entry.show.year, episodeCode: code,
                episodeTitle: next.title, progress: 0, remainingMinutes: nil,
                tmdbID: entry.show.ids.tmdb, showTraktID: sid, lastWatched: Date(), isUpNext: true)
            item.watchedEpisodes = entry.progress.completed
            item.airedEpisodes = entry.progress.aired
            return item
        }

        merged.append(contentsOf: additions.prefix(max(0, limit - merged.count)))
        return Array(merged.prefix(limit))
    }

    func remove(_ item: ContinueItem) async {
        guard let id = item.playbackID else { return }
        let before = continueItems
        continueItems.removeAll { $0.id == item.id }
        do { try await provider.removePlayback(id: id); saveCache() } catch { continueItems = before }
    }

    /// Geeft terug of de herinnering nu aan staat. Plan de echte notificatie in de app (UNUserNotificationCenter).
    @discardableResult
    func toggleReminder(_ item: UpcomingItem) -> Bool {
        if reminderIDs.remove(item.id) != nil { return false }
        reminderIDs.insert(item.id)
        return true
    }

    // MARK: Artwork (progressief: tekst eerst, beeld erna)

    private func enrichArtwork() async {
        guard let artwork else { return }
        // Met een fanart.tv-sleutel: banners opnieuw proberen (max 3x) als ze eerder ontbraken, en de cache
        // opnieuw opbouwen zodra de sleutel is ingevuld of gewijzigd.
        let hasKey = !(AppConfiguration.fanartAPIKey ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if hasKey != cachedWithFanartKey {
            artworkCache.removeAll()
            bannerAttempts.removeAll()
            cachedWithFanartKey = hasKey
        }
        func needsArtwork(_ id: Int) -> Bool {
            guard let cached = artworkCache[id] else { return true }
            return hasKey && cached.banner == nil && (bannerAttempts[id] ?? 0) < 3
        }
        var wanted: [(MediaKind, Int)] = []
        for i in continueItems { if let id = i.tmdbID, needsArtwork(id) { wanted.append((i.kind, id)) } }
        for i in upcoming { if let id = i.tmdbID, needsArtwork(id) { wanted.append((i.kind, id)) } }

        await withTaskGroup(of: (Int, Artwork?).self) { group in
            var queued = Set<Int>()
            for (kind, id) in wanted where queued.insert(id).inserted {
                group.addTask { (id, await artwork.artwork(for: kind, tmdbID: id)) }
            }
            for await (id, art) in group {
                guard let art else { continue }
                if hasKey { bannerAttempts[id, default: 0] += 1 }
                artworkCache[id] = art
                apply(art, to: id)
            }
        }
    }

    private func apply(_ art: Artwork, to tmdbID: Int) {
        for idx in continueItems.indices where continueItems[idx].tmdbID == tmdbID {
            continueItems[idx].backdropURL = art.backdrop
            continueItems[idx].logoURL = art.logo
            continueItems[idx].bannerURL = art.banner
        }
        for idx in upcoming.indices where upcoming[idx].tmdbID == tmdbID {
            upcoming[idx].backdropURL = art.backdrop
            upcoming[idx].logoURL = art.logo
        }
    }

}

// MARK: - Voorbeelddata (previews)

#if DEBUG
nonisolated struct MockTraktHomeProvider: TraktHomeProviding {
    func continueWatching(limit: Int) async throws -> [ContinueItem] {
        let now = Date()
        return [
            ContinueItem(id: "pb-1", playbackID: 1, kind: .episode, title: "Severance", year: 2022,
                         episodeCode: "S2E4", episodeTitle: "Woe's Hollow", progress: 0.54, remainingMinutes: 23,
                         tmdbID: 95396, showTraktID: 1, lastWatched: now, isUpNext: false),
            ContinueItem(id: "pb-2", playbackID: 2, kind: .movie, title: "Dune: Part Two", year: 2024,
                         episodeCode: nil, episodeTitle: nil, progress: 0.57, remainingMinutes: 71,
                         tmdbID: 693134, showTraktID: nil, lastWatched: now.addingTimeInterval(-3_600), isUpNext: false),
            ContinueItem(id: "pb-3", playbackID: 3, kind: .episode, title: "The Bear", year: 2022,
                         episodeCode: "S4E2", episodeTitle: "Bolognese", progress: 0.50, remainingMinutes: 19,
                         tmdbID: 136315, showTraktID: 3, lastWatched: now.addingTimeInterval(-86_400), isUpNext: false),
            ContinueItem(id: "next-4-S2E7", playbackID: nil, kind: .episode, title: "Andor", year: 2022,
                         episodeCode: "S2E7", episodeTitle: nil, progress: 0, remainingMinutes: 42,
                         tmdbID: 83867, showTraktID: 4, lastWatched: now.addingTimeInterval(-172_800), isUpNext: true)
        ]
    }

    func upcoming(days: Int) async throws -> [UpcomingItem] {
        let now = Date()
        func at(hours: Double) -> Date { now.addingTimeInterval(hours * 3_600) }
        return [
            UpcomingItem(id: "cal-1-S2E5", kind: .episode, title: "Severance", episodeCode: "S2E5", episodeTitle: "Trojan's Horse",
                         airDate: at(hours: 2.2), isDateOnly: false, runtimeMinutes: 52, tmdbID: 95396, showTraktID: 1),
            UpcomingItem(id: "cal-3-S4E3", kind: .episode, title: "The Bear", episodeCode: "S4E3", episodeTitle: nil,
                         airDate: at(hours: 3.7), isDateOnly: false, runtimeMinutes: 38, tmdbID: 136315, showTraktID: 3),
            UpcomingItem(id: "cal-4-S2E8", kind: .episode, title: "Andor", episodeCode: "S2E8", episodeTitle: "Seizoensfinale",
                         airDate: at(hours: 50), isDateOnly: false, runtimeMinutes: 48, tmdbID: 83867, showTraktID: 4),
            UpcomingItem(id: "cal-5-S6E1", kind: .episode, title: "Slow Horses", episodeCode: "S6E1", episodeTitle: nil,
                         airDate: at(hours: 27), isDateOnly: false, runtimeMinutes: 45, tmdbID: 95480, showTraktID: 5),
            UpcomingItem(id: "cal-m-6", kind: .movie, title: "Nieuwe film", episodeCode: nil, episodeTitle: nil,
                         airDate: at(hours: 96), isDateOnly: true, runtimeMinutes: 118, tmdbID: nil, showTraktID: nil),
            UpcomingItem(id: "cal-7-S3E1", kind: .episode, title: "Silo", episodeCode: "S3E1", episodeTitle: nil,
                         airDate: at(hours: 120), isDateOnly: false, runtimeMinutes: 50, tmdbID: 125988, showTraktID: 7),
            UpcomingItem(id: "cal-8-S4E1", kind: .episode, title: "Foundation", episodeCode: "S4E1", episodeTitle: nil,
                         airDate: at(hours: 144), isDateOnly: false, runtimeMinutes: 55, tmdbID: 93740, showTraktID: 8)
        ].sorted { $0.airDate < $1.airDate }
    }

    func removePlayback(id: Int) async throws {}
}
#endif
