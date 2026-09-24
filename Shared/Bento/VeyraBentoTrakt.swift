// VeyraBentoTrakt.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// Gegevenslaag voor de home-secties "Verder kijken" en "Binnenkort", gevoed door Trakt.
// Vereist VeyraBentoHeroModel.swift (HeroMoment / HeroContent).
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

nonisolated enum MediaKind: Sendable { case movie, episode }

nonisolated struct Artwork: Sendable, Equatable {
    var backdrop: URL?
    var logo: URL?
    var banner: URL? = nil
}

nonisolated struct ContinueItem: Identifiable, Hashable, Sendable {
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
        case let (c?, t?): return "\(c) · \(t)"
        case let (c?, nil): return c
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

nonisolated struct UpcomingItem: Identifiable, Equatable, Sendable {
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
        case let (c?, t?): return "\(c) · \(t)"
        case let (c?, nil): return c
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
    private let upNextMaxAgeDays: Int

    init(clientID: String,
         tokens: any TraktTokenProviding,
         session: URLSession = .shared,
         upNextLimit: Int = 40,
         upNextMaxAgeDays: Int = 365) {
        self.clientID = clientID
        self.tokens = tokens
        self.session = session
        self.upNextLimit = upNextLimit
        self.upNextMaxAgeDays = upNextMaxAgeDays
    }

    // MARK: Verder kijken

    func continueWatching(limit: Int) async throws -> [ContinueItem] {
        await withEpisodeCounts(try await baseContinueWatching(limit: limit))
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
        let wanted = items.filter { $0.kind == .episode && $0.airedEpisodes == nil && $0.showTraktID != nil }
        var counts: [String: (Int, Int)] = [:]
        var index = 0
        while index < wanted.count, !TraktHomeThrottle.shared.isBlocked {
            let chunk = Array(wanted[index..<min(index + 6, wanted.count)])
            index += 6
            let part = await withTaskGroup(of: (String, Int, Int)?.self) { group in
                for item in chunk {
                    guard let sid = item.showTraktID else { continue }
                    group.addTask { [self] in
                        guard let progress = await showProgress(sid),
                              let aired = progress.aired, let completed = progress.completed else { return nil }
                        return (item.id, completed, aired)
                    }
                }
                var found: [(String, Int, Int)] = []
                for await result in group { if let result { found.append(result) } }
                return found
            }
            for (id, completed, aired) in part { counts[id] = (completed, aired) }
        }
        return items.map { item in
            guard let (completed, aired) = counts[item.id] else { return item }
            var copy = item
            copy.watchedEpisodes = completed
            copy.airedEpisodes = aired
            return copy
        }
    }

    private func baseContinueWatching(limit: Int) async throws -> [ContinueItem] {
        let playback: [TraktPlaybackDTO] = try await get("sync/playback", query: [.init(name: "extended", value: "full")])

        // 1. Onderbroken items, nieuwste eerst, één per serie.
        var seenShows = Set<Int>()
        var items: [ContinueItem] = []
        for p in playback.sorted(by: { $0.pausedAt > $1.pausedAt }) {
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
                if let sid = s.ids.trakt, !seenShows.insert(sid).inserted { continue }
                let runtime = e.runtime ?? s.runtime
                items.append(ContinueItem(
                    id: "pb-\(p.id)", playbackID: p.id, kind: .episode, title: s.title, year: s.year,
                    episodeCode: Self.code(e), episodeTitle: e.title, progress: fraction,
                    remainingMinutes: runtime.map { Int((Double($0) * (1 - fraction)).rounded()) },
                    tmdbID: s.ids.tmdb, showTraktID: s.ids.trakt, lastWatched: p.pausedAt, isUpNext: false))
            default: continue
            }
        }
        if items.count >= limit { return Array(items.prefix(limit)) }

        // 2. Aanvullen met "volgende aflevering" van recent bekeken series.
        let cutoff = Date().addingTimeInterval(-Double(upNextMaxAgeDays) * 86_400)
        let watched: [TraktWatchedShowDTO] = (try? await get("sync/watched/shows", query: [.init(name: "extended", value: "noseasons")])) ?? []
        let candidates = watched
            .filter { $0.lastWatchedAt > cutoff }
            .filter { w in w.show.ids.trakt.map { !seenShows.contains($0) } ?? false }
            .sorted { $0.lastWatchedAt > $1.lastWatchedAt }
            .prefix(min(upNextLimit, limit - items.count))

        var upNext: [ContinueItem] = []
        let list = Array(candidates)
        var position = 0
        while position < list.count, !TraktHomeThrottle.shared.isBlocked {
            let chunk = Array(list[position..<min(position + 6, list.count)])
            position += 6
            let part = await withTaskGroup(of: ContinueItem?.self) { group in
                for w in chunk {
                    group.addTask { [self] in
                        guard let sid = w.show.ids.trakt,
                              let progress = await showProgress(sid),
                              let next = progress.nextEpisode else { return nil }
                        return ContinueItem(
                            id: "next-\(sid)-\(Self.code(next))", playbackID: nil, kind: .episode,
                            title: w.show.title, year: w.show.year, episodeCode: Self.code(next), episodeTitle: next.title,
                            progress: 0, remainingMinutes: next.runtime ?? w.show.runtime,
                            tmdbID: w.show.ids.tmdb, showTraktID: sid, lastWatched: w.lastWatchedAt, isUpNext: true)
                    }
                }
                var out: [ContinueItem] = []
                for await item in group { if let item { out.append(item) } }
                return out
            }
            upNext += part
        }
        items.append(contentsOf: upNext.sorted { $0.lastWatched > $1.lastWatched })
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

    private func send(_ path: String, method: String, query: [URLQueryItem]) async throws -> Data {
        var comps = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { comps.queryItems = query }
        var request = URLRequest(url: comps.url!)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2", forHTTPHeaderField: "trakt-api-version")
        request.setValue(clientID, forHTTPHeaderField: "trakt-api-key")
        request.setValue("Bearer \(try await tokens.accessToken())", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw TraktHomeError.invalidResponse }
        switch http.statusCode {
        case 200..<300: return data
        case 401: throw TraktHomeError.unauthorized
        case 429: throw TraktHomeError.rateLimited(retryAfter: http.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init))
        default: throw TraktHomeError.http(http.statusCode)
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

    private static func code(_ e: TraktEpisodeDTO) -> String { "S\(e.season)E\(e.number)" }

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
    }

    nonisolated private static func capture<T: Sendable>(_ work: @Sendable () async throws -> T) async -> Result<T, Error> {
        do { return .success(try await work()) } catch { return .failure(error) }
    }

    func load() async {
        phase = .loading
        let provider = self.provider
        async let cont = Self.capture { try await provider.continueWatching(limit: 80) }
        async let soon = Self.capture { try await provider.upcoming(days: 14) }
        let (c, u) = await (cont, soon)

        if case .success(let items) = c { continueItems = items }
        if case .success(let items) = u { upcoming = items }
        // Nieuw opgehaalde items hebben nog geen beeld: hergebruik wat al eerder is opgehaald.
        for (id, art) in artworkCache { apply(art, to: id) }

        switch (c, u) {
        case (.failure(let e), .failure): phase = .failed(e.localizedDescription)
        default: phase = .loaded
        }
        // Trakt-limiet met al bestaande gegevens: stil laten staan; de volgende verversing probeert het opnieuw.
        func isRateLimit(_ error: Error) -> Bool {
            if case TraktHomeError.rateLimited = error { return true }
            return false
        }
        if case .failure(let e) = c { notice = (isRateLimit(e) && !continueItems.isEmpty) ? nil : e.localizedDescription }
        else if case .failure(let e) = u { notice = (isRateLimit(e) && !upcoming.isEmpty) ? nil : e.localizedDescription }
        else { notice = nil }
        await enrichArtwork()
    }

    func remove(_ item: ContinueItem) async {
        guard let id = item.playbackID else { return }
        let before = continueItems
        continueItems.removeAll { $0.id == item.id }
        do { try await provider.removePlayback(id: id) } catch { continueItems = before }
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

    // MARK: Hero-mapping (zelfde HeroContent als VeyraHeroView)

    func heroContent(forContinue item: ContinueItem, now: Date = .now) -> HeroContent {
        var moments = [HeroMoment(
            id: item.id,
            label: item.isUpNext ? "VOLGENDE" : "HERVAT",
            title: item.episodeCode != nil ? (item.subtitle ?? item.title) : item.title,
            metaLine: item.metaText,
            backdropURL: item.backdropURL,
            progress: item.progress > 0 ? item.progress : nil,
            isLive: false,
            runtimeText: item.remainingMinutes.map { "\($0) min" },
            badges: [])]

        // "Straks": staat er een nieuwe aflevering van dezelfde serie in de Trakt-kalender?
        if let sid = item.showTraktID, let next = upcoming.first(where: { $0.showTraktID == sid }) {
            moments.append(HeroMoment(
                id: next.id, label: "STRAKS", title: next.subtitle ?? next.title,
                metaLine: VeyraHomeFormat.when(next.airDate, now: now, dateOnly: next.isDateOnly),
                backdropURL: next.backdropURL ?? item.backdropURL, progress: nil, isLive: false,
                runtimeText: next.runtimeMinutes.map { "\($0) min" }, badges: []))
        }
        return HeroContent(logoURL: item.logoURL, fallbackTitle: item.title, moments: moments)
    }

    func heroContent(forUpcoming item: UpcomingItem, now: Date = .now) -> HeroContent {
        let moment = HeroMoment(
            id: item.id, label: "BINNENKORT", title: item.subtitle ?? item.title,
            metaLine: "\(VeyraHomeFormat.when(item.airDate, now: now, dateOnly: item.isDateOnly)) · over \(VeyraHomeFormat.countdown(to: item.airDate, now: now))",
            backdropURL: item.backdropURL, progress: nil, isLive: false,
            runtimeText: item.runtimeMinutes.map { "\($0) min" }, badges: [])
        return HeroContent(logoURL: item.logoURL, fallbackTitle: item.title, moments: [moment])
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
