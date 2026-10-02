// VeyraBentoAdapters.swift — gedeeld (tvOS + iOS)
// Koppelt de bento-home aan de bestaande Veyra-bronnen, zonder die te wijzigen:
//   Trakt        <- TraktClient (zelfde sessie en token-verversing als de rest van de app)
//   Artwork      <- TMDB /images (backdrop + clearlogo, taal NL -> EN -> taalloos)
//   Sport        <- SportsStore (het Sport-menu; respecteert "score-spoilers verbergen")
//   Live nu      <- VeyraEPGStore (favorieten + recent bekeken zenders)
//   Titel openen <- VeyraBentoTitleDestination (zelfde route als "Verder kijken": film- of seriedetail)
// Alles is optioneel: geen Trakt-koppeling of geen IPTV betekent gewoon minder tegels.

import Foundation
import SwiftUI

// MARK: - Trakt

nonisolated struct VeyraTraktClientTokens: TraktTokenProviding {
    let client: TraktClient
    func accessToken() async throws -> String { try await client.validAccessToken() }
}

/// Meldt `notLinked` zolang Trakt niet is gekoppeld; de home toont dan bovenaan een korte melding.
nonisolated struct VeyraTraktHomeSource: TraktHomeProviding {
    let client: TraktClient

    private func api() async -> TraktHomeAPI? {
        await MainActor.run { () -> TraktHomeAPI? in
            guard client.isAuthenticated, let id = client.clientID else { return nil }
            return TraktHomeAPI(clientID: id, tokens: VeyraTraktClientTokens(client: client))
        }
    }

    func continueWatching(limit: Int) async throws -> [ContinueItem] {
        guard let api = await api() else { throw TraktHomeError.notLinked }
        return try await api.continueWatching(limit: limit)
    }

    func upcoming(days: Int) async throws -> [UpcomingItem] {
        guard let api = await api() else { throw TraktHomeError.notLinked }
        return try await api.upcoming(days: days)
    }

    func removePlayback(id: Int) async throws {
        guard let api = await api() else { return }
        try await api.removePlayback(id: id)
    }
}

// MARK: - TMDB-artwork

nonisolated struct VeyraTMDBArtwork: ArtworkProviding {
    private nonisolated struct Images: Decodable {
        nonisolated struct Backdrop: Decodable {
            let file_path: String
            let iso_639_1: String?
            let vote_average: Double
        }
        let backdrops: [Backdrop]
        let logos: [TMDBLogo]
    }

    func artwork(for kind: MediaKind, tmdbID: Int) async -> Artwork? {
        let token: String? = await MainActor.run { AppConfiguration.tmdbReadAccessToken }
        guard let token, !token.isEmpty else { return nil }

        let path = kind == .movie ? "movie" : "tv"
        guard var components = URLComponents(string: "\(VeyraEndpoints.tmdb)/\(path)/\(tmdbID)/images") else { return nil }
        components.queryItems = [URLQueryItem(name: "include_image_language", value: "nl,en,null")]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let images = try? JSONDecoder().decode(Images.self, from: data) else { return nil }

        let textless = images.backdrops.filter { $0.iso_639_1 == nil }
        let bestBackdrop = (textless.isEmpty ? images.backdrops : textless).max { $0.vote_average < $1.vote_average }
        let banner = await fanartBanner(kind: kind, tmdbID: tmdbID, token: token)
        // Fase 3 stap 2 (artwork-engine-spec §29/§30/§44): logo via de centrale
        // `ArtworkResolver` i.p.v. hier altijd rechtstreeks uit deze eigen `/images`-aanvraag te
        // plukken -- respecteert zo ook een gekozen AIOMetadata-addon voor de Home-hero/Bento-
        // tegels. De backdrop- en fanart.tv-banner-aanroepen blijven ongewijzigd (geen
        // ClearLogo, geen dubbele logica elders).
        let logo = await ArtworkResolver.shared.clearLogoURL(
            for: MediaItem(title: "", type: kind == .movie ? .movie : .series, tmdbID: tmdbID)
        )
        return Artwork(
            backdrop: bestBackdrop.flatMap { URL(string: "https://image.tmdb.org/t/p/w1280\($0.file_path)") },
            logo: logo,
            banner: banner)
    }

    // MARK: fanart.tv-banners (breed formaat, ±1000×185)

    private nonisolated struct FanartResponse: Decodable {
        nonisolated struct Item: Decodable {
            let url: String
            let lang: String?
            let likes: String?
        }
        let tvbanner: [Item]?
        let moviebanner: [Item]?
    }

    private nonisolated struct ExternalIDs: Decodable { let tvdb_id: Int? }

    /// Alleen actief met een fanart.tv-sleutel (Instellingen > Account > fanart.tv).
    /// Films: TMDB-id · series: TheTVDB-id (via TMDB `external_ids`).
    private func fanartBanner(kind: MediaKind, tmdbID: Int, token: String) async -> URL? {
        let stored: String? = await MainActor.run { AppConfiguration.fanartAPIKey }
        guard let key = stored?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty else { return nil }

        var identifier = tmdbID
        var path = "movies"
        if kind == .episode {
            guard let url = URL(string: "\(VeyraEndpoints.tmdb)/tv/\(tmdbID)/external_ids") else { return nil }
            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  let ids = try? JSONDecoder().decode(ExternalIDs.self, from: data),
                  let tvdb = ids.tvdb_id else { return nil }
            identifier = tvdb
            path = "tv"
        }

        guard let url = URL(string: "\(VeyraEndpoints.fanart)/\(path)/\(identifier)?api_key=\(key)") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let decoded = try? JSONDecoder().decode(FanartResponse.self, from: data) else { return nil }

        let items = (kind == .movie ? decoded.moviebanner : decoded.tvbanner) ?? []
        func rank(_ item: FanartResponse.Item) -> (Int, Int) {
            let language = item.lang == "nl" ? 0 : (item.lang == "en" ? 1 : 2)
            return (language, -(Int(item.likes ?? "0") ?? 0))
        }
        let best = items.min { rank($0) < rank($1) }
        return best.flatMap { URL(string: $0.url.replacingOccurrences(of: "http://", with: "https://")) }
    }
}

// MARK: - Sport-menu

@MainActor
extension SportEvent {
    /// Vertaalt een wedstrijd uit het Sport-menu. Uitgestelde wedstrijden vallen weg.
    init?(match: SportsMatch, hideScore: Bool) {
        guard match.phase != .postponed else { return nil }

        let minutes: Double
        switch match.league.sport {
        case .americanFootball: minutes = 200
        case .basketball: minutes = 150
        case .football: minutes = 110
        }

        let hint: PhaseHint
        switch match.phase {
        case .live: hint = .live
        case .finished: hint = .finished
        default: hint = .scheduled
        }

        var score: SportScore?
        if match.showsScore, !hideScore {
            score = SportScore(home: Int(match.homeScore ?? "") ?? 0,
                               away: Int(match.awayScore ?? "") ?? 0,
                               minute: match.phase == .live && !match.detail.isEmpty ? match.detail : nil)
        }

        self.init(
            id: match.id,
            title: "\(match.home.name) – \(match.away.name)",
            home: match.home.name,
            away: match.away.name,
            competition: match.league.name,
            start: match.date,
            end: match.date.addingTimeInterval(minutes * 60),
            channelID: "",
            channelNumber: 0,
            channelName: "",
            health: .good,
            canCatchUp: false,
            alternativeSources: 0,
            backdropURL: nil,
            score: score,
            phaseHint: hint,
            homeLogoURL: match.home.logoURL ?? SportsTeam.fallbackLogoURL(abbreviation: match.home.abbreviation),
            awayLogoURL: match.away.logoURL ?? SportsTeam.fallbackLogoURL(abbreviation: match.away.abbreviation),
            leagueSymbol: match.league.symbol,
            homeTeamID: match.home.id,
            awayTeamID: match.away.id,
            situation: match.situation,
            tvBroadcast: match.tvBroadcast)
    }
}

/// Bron voor de home-sectie Sport: exact de data van het Sport-menu (SportsStore).
nonisolated struct SportsStoreProvider: SportHomeProviding {
    let store: SportsStore

    func events(from: Date, to: Date) async throws -> [SportEvent] {
        let today = await load(day: Date())
        let now = Date()
        // Elke aangezette competitie krijgt haar komende wedstrijden, ook als een
        // andere competitie vandaag al speelt (bijv. NFL morgen, Pro League na een pauze).
        let leagues = await MainActor.run {
            SportsLeague.all.filter { SportsDisplayPreferences.isLeagueEnabled($0.id) }
        }
        let enabledIDs = Set(leagues.map(\.id))
        if let cached = await SportFutureCache.shared.events(now: now, enabledIDs: enabledIDs) {
            return today + cached
        }

        let start = Calendar.current.date(byAdding: .day, value: 1,
                                          to: Calendar.current.startOfDay(for: now))!
        let end = Calendar.current.date(byAdding: .day, value: 1,
                                        to: Calendar.current.startOfDay(for: to))!
        let provider = await MainActor.run { ESPNScoreProvider() }
        var matches: [SportsMatch] = []
        var succeeded = 0
        // Beperk gelijktijdige aanvragen; een grote piek leidde tot ontbrekende
        // competities. Een dagaanvraag vangt gateways op die maandwaarden weigeren.
        for batchStart in stride(from: 0, to: leagues.count, by: 4) {
            let batch = leagues[batchStart..<min(batchStart + 4, leagues.count)]
            await withTaskGroup(of: [SportsMatch]?.self) { group in
                for league in batch {
                    group.addTask { @MainActor in
                        do {
                            return try await provider.matches(league: league, from: start, to: end)
                        } catch {
                            return try? await provider.matches(league: league, date: start)
                        }
                    }
                }
                for await part in group {
                    if let part {
                        matches += part
                        succeeded += 1
                    }
                }
            }
        }
        let upcoming = await makeEvents(matches: matches.filter { $0.date > now })
        if succeeded > 0 {
            await SportFutureCache.shared.store(upcoming, now: now, enabledIDs: enabledIDs)
        }
        return today + upcoming
    }

    private func load(day: Date) async -> [SportEvent] {
        // Eigen, per dag gecachete aanvraag: het gedeelde SportsStore wist zijn lijst bij een dagwissel en
        // liet gelijktijdige aanvragen leeg terugkeren ("Vandaag & straks" bleef dan leeg).
        let matches = await SportDayCache.shared.matches(day: day)
        return await makeEvents(matches: matches)
    }

    private func makeEvents(matches: [SportsMatch]) async -> [SportEvent] {
        let (events, paths) = await MainActor.run { () -> ([SportEvent], [String: String]) in
            let hideScore = UserDefaults.standard.bool(forKey: GeneralSettingsDefaults.hideScoreSpoilersKey)
            var paths: [String: String] = [:]
            for match in matches { paths[match.league.name] = match.league.path }
            return (matches.compactMap { SportEvent(match: $0, hideScore: hideScore) }, paths)
        }

        // Competitielogo's (NFL, Champions League, ...) als zachte achtergrond.
        var logos: [String: URL] = [:]
        for (name, path) in paths {
            if let url = await VeyraLeagueLogos.shared.logo(path: path) { logos[name] = url }
        }
        return events.map { event in
            var copy = event
            if let competition = event.competition { copy.leagueLogoURL = logos[competition] }
            return copy
        }
    }
}

/// Haalt het logo van een competitie één keer op uit het ESPN-scoreboard (`leagues[0].logos`).
actor VeyraLeagueLogos {
    static let shared = VeyraLeagueLogos()
    private var cache: [String: URL?] = [:]

    private nonisolated struct Scoreboard: Decodable {
        nonisolated struct League: Decodable {
            nonisolated struct Logo: Decodable {
                let href: String
                let rel: [String]?
            }
            let logos: [Logo]?
        }
        let leagues: [League]?
    }

    func logo(path: String) async -> URL? {
        if let cached = cache[path] { return cached }
        guard let url = URL(string: "\(VeyraEndpoints.sports)/\(path)/scoreboard?limit=1") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let board = try? JSONDecoder().decode(Scoreboard.self, from: data) else { return nil }
        let logos = board.leagues?.first?.logos ?? []
        // Voor een donkere achtergrond: liefst de "dark"-variant.
        let best = logos.first { $0.rel?.contains("dark") == true && $0.rel?.contains("default") == true }
            ?? logos.first { $0.rel?.contains("dark") == true }
            ?? logos.first
        let result = best.flatMap { URL(string: $0.href.replacingOccurrences(of: "http://", with: "https://")) }
        cache[path] = .some(result)
        return result
    }
}

/// Haalt alle competities voor één dag parallel op en onthoudt het resultaat (vandaag 55 s, latere dagen 15 min).
/// Gelijktijdige aanvragen voor dezelfde dag delen één ophaalronde.
@MainActor
private final class SportDayCache {
    static let shared = SportDayCache()
    private var days: [Date: (at: Date, matches: [SportsMatch])] = [:]
    private var pending: [Date: Task<[SportsMatch]?, Never>] = [:]

    func matches(day: Date) async -> [SportsMatch] {
        let calendar = Calendar.current
        let key = calendar.startOfDay(for: day)
        let ttl: TimeInterval = key == calendar.startOfDay(for: Date()) ? 55 : 900
        if let hit = days[key], Date().timeIntervalSince(hit.at) < ttl { return hit.matches }
        if let task = pending[key] { return await task.value ?? days[key]?.matches ?? [] }

        let task = Task<[SportsMatch]?, Never> { @MainActor in
            let provider = ESPNScoreProvider()
            var all: [SportsMatch] = []
            var succeeded = 0
            await withTaskGroup(of: [SportsMatch]?.self) { group in
                for league in SportsLeague.all where SportsDisplayPreferences.isLeagueEnabled(league.id) {
                    group.addTask { @MainActor in try? await provider.matches(league: league, date: key) }
                }
                for await part in group {
                    if let part { all += part; succeeded += 1 }
                }
            }
            guard succeeded > 0 else { return nil }
            return all.sorted { $0.date == $1.date ? $0.id < $1.id : $0.date < $1.date }
        }
        pending[key] = task
        let result = await task.value
        pending[key] = nil
        if let result { days[key] = (Date(), result) }
        return result ?? days[key]?.matches ?? []
    }
}

/// Onthoudt komende wedstrijden 15 minuten, zodat de minuut-verversing geen maandaanvragen herhaalt.
private actor SportFutureCache {
    static let shared = SportFutureCache()
    private var stored: [SportEvent] = []
    private var fetchedAt: Date?
    private var enabledIDs: Set<String> = []

    func events(now: Date, enabledIDs: Set<String>) -> [SportEvent]? {
        guard let fetchedAt, now.timeIntervalSince(fetchedAt) < 900,
              self.enabledIDs == enabledIDs else { return nil }
        let still = stored.filter { $0.start > now }
        return still
    }

    func store(_ events: [SportEvent], now: Date, enabledIDs: Set<String>) {
        stored = events
        fetchedAt = now
        self.enabledIDs = enabledIDs
    }
}

// MARK: - Live nu (EPG)

/// Zet favorieten en recent bekeken IPTV-zenders om naar het bento-model.
/// Herlaadt de gids hooguit elke 10 minuten; daartussen wordt de bestaande gids hergebruikt.
@MainActor
final class VeyraLiveGuideSource {
    private let guide = VeyraEPGStore()
    private var lastReload: Date?

    /// Bronnen om een zender rechtstreeks af te spelen (zet hem ook bovenaan "recent bekeken").
    func playableSource(forChannelID id: String) -> PlayableSource? {
        guard let row = guide.channels.first(where: { $0.id == id }) else { return nil }
        return guide.play(row)
    }

    private func reloadIfNeeded() async {
        if lastReload == nil || Date().timeIntervalSince(lastReload ?? .distantPast) > 600 {
            guide.reloadID = UUID()
            await guide.reload()
            lastReload = Date()
        }
    }

    /// Zenders waarvan de gids rond de aftrap een programma met deze teams heeft (zie `SportChannelMatcher`).
    func sportChannels(teams: [String], start: Date) async -> [SportChannelMatch] {
        await reloadIfNeeded()
        // De actieve provider staat uit voor discovery (Instellingen > IPTV) -- dan ook geen
        // sportwedstrijden meer matchen op zijn zenders, net als bij "Nieuw toegevoegd"/"Nieuw
        // op je zenders". `allChannels` hieronder blijft bewust ongefilterd op categorie/zender-
        // zichtbaarheid (zie het bestaande commentaar erbij), enkel de provider-aan/uit-schakelaar
        // geldt hier ook.
        if let activeProviderID = guide.activeProviderID, !IPTVDiscoveryVisibility.shared.isProviderEnabled(activeProviderID) {
            return []
        }
        let index = guide.programmeIndex
        // `allChannels` i.p.v. `channels`: sportwedstrijd-matching moet alle
        // providerzenders met een EPG-naam-match kunnen vinden, ook zenders die
        // de gebruiker niet zichtbaar heeft gezet in de Live TV-instellingen.
        let channels = guide.allChannels.map { row in
            SportGuideChannel(
                id: row.id,
                name: ChannelNameOverrideStore.effectiveName(channelID: row.channel.id, defaultName: row.channel.name),
                logoURL: ChannelLogoOverrideStore.effectiveLogoURL(channelID: row.channel.id, defaultLogoURL: row.channel.logoURL),
                tvgID: (row.channel.tvgID ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return await Task.detached(priority: .userInitiated) {
            SportChannelMatcher.matches(teams: teams, start: start, index: index, channels: channels)
        }.value
    }

    func channels() async -> [EPGChannel] {
        await reloadIfNeeded()

        var rows = guide.favoriteRows
        var seen = Set(rows.map(\.id))
        for id in guide.recent {
            if let row = guide.channels.first(where: { $0.id == id }), seen.insert(row.id).inserted { rows.append(row) }
        }

        // Geen favorieten of recent bekeken zenders: neem zenders die programmagegevens hebben.
        if rows.isEmpty {
            rows = Array(guide.channels.filter { !guide.programmes(for: $0).isEmpty }.prefix(24))
        }

        let now = Date()
        return rows.enumerated().map { index, row in
            let group = (row.channel.group ?? "").lowercased()
            let isSportsChannel = group.contains("sport") || row.channel.name.lowercased().contains("sport")
            let programmes = guide.programmes(for: row)
                .filter { $0.end > now.addingTimeInterval(-60) }
                .sorted { $0.start < $1.start }
                .prefix(4)
            return EPGChannel(
                id: row.id, number: index + 1,
                name: ChannelNameOverrideStore.effectiveName(channelID: row.channel.id, defaultName: row.channel.name),
                logoURL: ChannelLogoOverrideStore.effectiveLogoURL(channelID: row.channel.id, defaultLogoURL: row.channel.logoURL),
                health: .good, isFavorite: guide.favorites.contains(row.id),
                recentRank: guide.recent.firstIndex(of: row.id),
                programs: programmes.map { p in
                    EPGProgram(id: p.id, title: p.title, subtitle: p.subtitle.isEmpty ? nil : p.subtitle,
                               description: p.summary.isEmpty ? nil : p.summary, start: p.start, end: p.end,
                               backdropURL: nil, isSports: isSportsChannel, isInWatchlist: false, canCatchUp: false)
                })
        }
    }
}

// MARK: - Bronnen (Hub · AIOStreams · IPTV)

/// Bereikbaarheid van de bronnen die je in Veyra hebt ingesteld: goed (<2 s), traag of onbereikbaar.
nonisolated struct VeyraSourceStatus: SourceStatusProviding {
    func sources() async -> [BentoSource] {
        let targets: [(String, String, URL)] = await MainActor.run {
            var out: [(String, String, URL)] = []
            if let hub = MediaServerStore().load().first(where: { $0.isVeyraHub }) {
                out.append(("hub", "Veyra Hub", hub.serverURL))
            }
            if let aio = AddonStore().load().first(where: { $0.kind == .aioStreams && $0.isEnabled }) {
                out.append(("aio", "AIOStreams", aio.baseURL))
            }
            if let configuration = try? IPTVConfigurationStore().load(), case .xtream(let xtream) = configuration {
                out.append(("iptv", "IPTV", xtream.serverURL))
            }
            return out
        }

        return await withTaskGroup(of: (Int, BentoSource).self) { group in
            for (index, target) in targets.enumerated() {
                group.addTask { (index, BentoSource(id: target.0, name: target.1, health: await Self.probe(target.2))) }
            }
            var result: [(Int, BentoSource)] = []
            for await item in group { result.append(item) }
            return result.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    private static func probe(_ url: URL) async -> SourceHealth {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5
        let start = Date()
        do {
            _ = try await URLSession.shared.data(for: request)
            return Date().timeIntervalSince(start) > 2 ? .degraded : .good
        } catch {
            return .down
        }
    }
}

// MARK: - TMDB: nieuw uitgebrachte films en series

nonisolated struct BentoTMDBTitle: Identifiable, Hashable, Sendable {
    let id: Int              // TMDB-id
    let kind: MediaKind
    let title: String
    let posterURL: URL?
    var backdropURL: URL? = nil
    // Alleen gebruikt om "nieuwste eerst" te kunnen sorteren op de
    // streamingdienst-overzichtspagina; niet gevuld door elke bron.
    var releaseDate: Date? = nil
    // Voor de Better-Posters badge (genre/beoordeling) op de Home-shelves.
    var genreIDs: [Int] = []
    var voteAverage: Double? = nil
}

/// Recent uitgebrachte titels (films ≤ 45 dagen, series ≤ 60 dagen), op populariteit, via TMDB `discover`.
nonisolated struct VeyraTMDBReleases: Sendable {
    private nonisolated struct Page: Decodable {
        nonisolated struct Item: Decodable {
            let id: Int
            let title: String?
            let name: String?
            let poster_path: String?
            let genre_ids: [Int]?
            let vote_average: Double?
            let original_language: String?
            let release_date: String?
            let first_air_date: String?
        }
        let results: [Item]
    }

    func movies() async -> [BentoTMDBTitle] { await fetch(.movie) }
    func series() async -> [BentoTMDBTitle] { await fetch(.episode) }

    private func fetch(_ kind: MediaKind) async -> [BentoTMDBTitle] {
        let token: String? = await MainActor.run { AppConfiguration.tmdbReadAccessToken }
        guard let token, !token.isEmpty else { return [] }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let today = Date()
        let isMovie = kind == .movie
        let from = today.addingTimeInterval(-(isMovie ? 45 : 60) * 86_400)

        guard var components = URLComponents(string: "\(VeyraEndpoints.tmdb)/discover/\(isMovie ? "movie" : "tv")") else { return [] }
        var items: [URLQueryItem] = [
            .init(name: "language", value: "nl-BE"),
            .init(name: "sort_by", value: "popularity.desc"),
            .init(name: "include_adult", value: "false"),
            .init(name: isMovie ? "primary_release_date.gte" : "first_air_date.gte", value: formatter.string(from: from)),
            .init(name: isMovie ? "primary_release_date.lte" : "first_air_date.lte", value: formatter.string(from: today))
        ]
        if isMovie { items.append(.init(name: "region", value: "BE")) }
        components.queryItems = items
        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let page = try? JSONDecoder().decode(Page.self, from: data) else { return [] }

        return page.results.compactMap { item in
            guard TMDBCatalogLanguageFilter.allows(item.original_language),
                  let poster = item.poster_path, let title = item.title ?? item.name else { return nil }
            let dateString = item.release_date ?? item.first_air_date
            let releaseDate = dateString.flatMap { formatter.date(from: $0) }
            return BentoTMDBTitle(id: item.id, kind: kind, title: title,
                                  posterURL: URL(string: "https://image.tmdb.org/t/p/w342\(poster)"),
                                  releaseDate: releaseDate,
                                  genreIDs: item.genre_ids ?? [],
                                  voteAverage: item.vote_average)
        }
        .prefix(20).map { $0 }
    }
}

// MARK: - Posters

enum VeyraPosterURL {
    /// Zware TMDB-varianten (original / w1280) worden vervangen door w342; andere URL's blijven ongewijzigd.
    nonisolated static func optimized(_ url: URL?) -> URL? {
        guard let url else { return nil }
        guard url.host == "image.tmdb.org" else { return url }
        let text = url.absoluteString
            .replacingOccurrences(of: "/t/p/original/", with: "/t/p/w342/")
            .replacingOccurrences(of: "/t/p/w1280/", with: "/t/p/w342/")
            .replacingOccurrences(of: "/t/p/w780/", with: "/t/p/w342/")
            .replacingOccurrences(of: "/t/p/w500/", with: "/t/p/w342/")
        return URL(string: text) ?? url
    }
}

/// Zoekt een TMDB-poster op titel voor IPTV-items zonder (werkende) afbeelding.
actor VeyraPosterSearch {
    static let shared = VeyraPosterSearch()
    private var cache: [String: URL?] = [:]

    static func posterURL(title: String, kind: MediaKind) async -> URL? {
        await shared.lookup(title: title, kind: kind)
    }

    private func lookup(title: String, kind: MediaKind) async -> URL? {
        let query = Self.clean(title)
        guard !query.isEmpty else { return nil }
        let key = "\(kind == .movie ? "m" : "t")|\(query.lowercased())"
        if let cached = cache[key] { return cached }

        let token: String? = await MainActor.run { AppConfiguration.tmdbReadAccessToken }
        guard let token, !token.isEmpty,
              var components = URLComponents(string: "\(VeyraEndpoints.tmdb)/search/\(kind == .movie ? "movie" : "tv")") else { return nil }
        components.queryItems = [.init(name: "query", value: query), .init(name: "language", value: "nl-BE"),
                                 .init(name: "include_adult", value: "false")]
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        struct Page: Decodable { struct Item: Decodable { let poster_path: String? }; let results: [Item] }
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let page = try? JSONDecoder().decode(Page.self, from: data) else { return nil }

        let result = page.results.compactMap(\.poster_path).first.flatMap { URL(string: "https://image.tmdb.org/t/p/w342\($0)") }
        cache[key] = .some(result)
        return result
    }

    /// "NL - Dune: Part Two (2024) HD" -> "Dune: Part Two"
    private static func clean(_ raw: String) -> String {
        var text = raw
        for pattern in ["\\([^)]*\\)", "\\[[^\\]]*\\]", "^[A-Za-z]{2,3}\\s*[-|:]\\s+", "\\b(4K|UHD|FHD|HD|SD|1080p|720p)\\b"] {
            text = text.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - IPTV: nieuw toegevoegde films en series

/// VOD van alle gekoppelde Xtream-providers. Per provider blijft de catalogus
/// zes uur in de schijf-cache; zichtbaarheid wordt altijd opnieuw toegepast.
@MainActor
final class VeyraIPTVNewSource {
    private let maxAge: TimeInterval = 6 * 3600
    private let limit = 20

    /// Zichtbaar volgens Instellingen > IPTV (categorie + item) EN volgens
    /// `IPTVProviderEnablement` (provider uit voor discovery) -- via de
    /// gedeelde `IPTVDiscoveryVisibility`-laag, zodat "Nieuw toegevoegd" dezelfde
    /// regels volgt als elke andere discovery-sectie.
    nonisolated private static func isVisible(_ item: IPTVVODItem, provider: IPTVStoredProvider) -> Bool {
        let categoryID = (item.categoryID?.isEmpty == false) ? item.categoryID : nil
        return IPTVDiscoveryVisibility.shared.isVODItemVisible(item.id, categoryID: categoryID, provider: provider)
    }

    nonisolated private static func isVisible(_ series: XtreamSeriesItem, provider: IPTVStoredProvider) -> Bool {
        let categoryID = (series.categoryID?.isEmpty == false) ? series.categoryID : nil
        return IPTVDiscoveryVisibility.shared.isSeriesItemVisible(String(series.id), categoryID: categoryID, provider: provider)
    }

    /// Alleen providers die voor discovery ingeschakeld staan -- een provider die
    /// de gebruiker hier uitzette mag niet meer in "Nieuw toegevoegd" verschijnen,
    /// ook al staat hij nog gewoon in zijn eigen Live TV/VOD-schermen.
    private func providers() -> [IPTVStoredProvider] {
        SourceOrderDefaults.sortedProviders(
            IPTVDiscoveryVisibility.shared.enabledProviders(),
            order: SourceOrderDefaults.loadIPTVProviderOrder(),
            id: { $0.id }
        )
    }

    func films() async -> [IPTVHomeFilm] {
        let providers = providers()
        let resultLimit = max(limit, providers.count)
        let batches = await withTaskGroup(of: [IPTVHomeFilm].self) { group in
            for (index, provider) in providers.enumerated() {
                guard case .xtream = provider.configuration else { continue }
                group.addTask {
                    await self.films(from: provider, order: index)
                }
            }
            var values: [IPTVHomeFilm] = []
            for await batch in group { values.append(contentsOf: batch) }
            return values
        }
        return Array(batches.sorted {
            if $0.providerRank != $1.providerRank {
                return $0.providerRank < $1.providerRank
            }
            if $0.item.added != $1.item.added {
                return ($0.item.added ?? .distantPast) > ($1.item.added ?? .distantPast)
            }
            if $0.providerOrder != $1.providerOrder {
                return $0.providerOrder < $1.providerOrder
            }
            return $0.item.id > $1.item.id
        }.prefix(resultLimit))
    }

    private func films(from provider: IPTVStoredProvider, order: Int) async -> [IPTVHomeFilm] {
        guard case .xtream(let xtream) = provider.configuration else { return [] }
        let maxAge = self.maxAge
        let limit = self.limit
        // Schijf-lees/decode/filter/sorteer (mogelijk duizenden items) hoort niet op de
        // main actor -- alleen `self` is @MainActor, dit werk zelf raakt geen UI-state
        // aan, dus een losse achtergrond-Task houdt de UI/launch-animatie vlot.
        return await Task.detached(priority: .userInitiated) {
            let key = "recentlyAdded.vod.raw.\(provider.configuration.providerIdentifier)"
            let cached = IPTVDiskCache.read([IPTVVODItem].self, key: key)
            let catalog: [IPTVVODItem]
            if let cached, Date().timeIntervalSince(cached.savedAt) < maxAge {
                catalog = cached.value
            } else {
                do {
                    catalog = try await IPTVService().loadXtreamVOD(configuration: xtream)
                    IPTVDiskCache.write(catalog, key: key)
                    if !catalog.isEmpty {
                        await IPTVDiscoverySnapshotStore.shared.recordSuccessfulFetch(
                            providerID: provider.id,
                            contentType: "vod",
                            currentIDs: Set(catalog.map(\.id))
                        )
                    }
                } catch {
                    catalog = cached?.value ?? []
                }
            }
            var seenIDs = Set<String>()
            let visible = catalog.filter {
                VeyraIPTVNewSource.isVisible($0, provider: provider) && seenIDs.insert($0.id).inserted
            }.sorted {
                if $0.added != $1.added {
                    return ($0.added ?? .distantPast) > ($1.added ?? .distantPast)
                }
                let firstID = Int($0.id.split(separator: "-").last ?? "") ?? 0
                let secondID = Int($1.id.split(separator: "-").last ?? "") ?? 0
                return firstID > secondID
            }
            return visible.prefix(limit).enumerated().map { rank, item in
                IPTVHomeFilm(providerID: provider.id, providerName: provider.displayName,
                             providerOrder: order, providerRank: rank, item: item)
            }
        }.value
    }

    func series() async -> [IPTVHomeSeries] {
        let providers = providers()
        let resultLimit = max(limit, providers.count)
        let batches = await withTaskGroup(of: [IPTVHomeSeries].self) { group in
            for (index, provider) in providers.enumerated() {
                guard case .xtream = provider.configuration else { continue }
                group.addTask {
                    await self.series(from: provider, order: index)
                }
            }
            var values: [IPTVHomeSeries] = []
            for await batch in group { values.append(contentsOf: batch) }
            return values
        }
        return Array(batches.sorted {
            if $0.providerRank != $1.providerRank {
                return $0.providerRank < $1.providerRank
            }
            if $0.item.added != $1.item.added {
                return ($0.item.added ?? .distantPast) > ($1.item.added ?? .distantPast)
            }
            if $0.providerOrder != $1.providerOrder {
                return $0.providerOrder < $1.providerOrder
            }
            return $0.item.id > $1.item.id
        }.prefix(resultLimit))
    }

    private func series(from provider: IPTVStoredProvider, order: Int) async -> [IPTVHomeSeries] {
        guard case .xtream(let xtream) = provider.configuration else { return [] }
        let maxAge = self.maxAge
        let limit = self.limit
        return await Task.detached(priority: .userInitiated) {
            let key = "recentlyAdded.series.raw.\(provider.configuration.providerIdentifier)"
            let cached = IPTVDiskCache.read([XtreamSeriesItem].self, key: key)
            let catalog: [XtreamSeriesItem]
            if let cached, Date().timeIntervalSince(cached.savedAt) < maxAge {
                catalog = cached.value
            } else {
                do {
                    catalog = try await IPTVService().loadXtreamSeries(configuration: xtream)
                    IPTVDiskCache.write(catalog, key: key)
                    if !catalog.isEmpty {
                        await IPTVDiscoverySnapshotStore.shared.recordSuccessfulFetch(
                            providerID: provider.id,
                            contentType: "series",
                            currentIDs: Set(catalog.map { String($0.id) })
                        )
                    }
                } catch {
                    catalog = cached?.value ?? []
                }
            }
            var seenIDs = Set<Int>()
            let visible = catalog.filter {
                VeyraIPTVNewSource.isVisible($0, provider: provider) && seenIDs.insert($0.id).inserted
            }.sorted {
                if $0.added != $1.added {
                    return ($0.added ?? .distantPast) > ($1.added ?? .distantPast)
                }
                return $0.id > $1.id
            }
            return visible.prefix(limit).enumerated().map { rank, item in
                IPTVHomeSeries(providerID: provider.id, providerName: provider.displayName,
                               providerOrder: order, providerRank: rank, item: item)
            }
        }.value
    }
}

// MARK: - Gedeelde instanties

/// Eén set modellen voor de hele app, zodat terugkeren naar Home niet alles opnieuw opbouwt.
@MainActor
final class VeyraBentoServices {
    static let shared = VeyraBentoServices()

    let bento: VeyraBentoViewModel
    let sport: VeyraSportViewModel
    private let liveGuide: VeyraLiveGuideSource

    func playableSource(forChannelID id: String) -> PlayableSource? {
        liveGuide.playableSource(forChannelID: id)
    }

    func sportChannels(teams: [String], start: Date) async -> [SportChannelMatch] {
        await liveGuide.sportChannels(teams: teams, start: start)
    }

    private init() {
        let home = VeyraHomeViewModel(
            provider: VeyraTraktHomeSource(client: TraktStore.shared.client),
            artwork: VeyraTMDBArtwork())
        let guide = VeyraLiveGuideSource()
        liveGuide = guide
        let iptv = VeyraIPTVNewSource()
        bento = VeyraBentoViewModel(home: home,
                                    epg: { await guide.channels() },
                                    iptvFilms: { await iptv.films() },
                                    iptvSeries: { await iptv.series() },
                                    releasesFilms: { await VeyraTMDBReleases().movies() },
                                    releasesSeries: { await VeyraTMDBReleases().series() },
                                    regionalReleases: {
                                        await RegionalReleaseRepository.shared.refresh(
                                            context: .defaultBelgiumFlanders())
                                    },
                                    streaming: { await VeyraCatalogSource().providers() },
                                    collections: { await VeyraCatalogSource().collections() })
        sport = VeyraSportViewModel(provider: SportsStoreProvider(store: SportsStore()))
    }
}

// MARK: - Titel openen

/// Opent een "Verder kijken"-item op dezelfde manier als de Trakt-rijen: film -> MovieDetailView, serie -> SeriesDetailView.
struct VeyraBentoTitleDestination: View {
    let kind: MediaKind
    let tmdbID: Int?

    init(item: ContinueItem) {
        kind = item.kind
        tmdbID = item.tmdbID
    }

    init(kind: MediaKind, tmdbID: Int) {
        self.kind = kind
        self.tmdbID = tmdbID
    }

    @State private var movie: MediaItem?
    @State private var series: TMDBSeries?
    @State private var failed = false

    var body: some View {
        Group {
            if let movie {
                MovieDetailView(movie: movie)
            } else if let series {
                SeriesDetailView(series: series)
            } else if failed {
                Text("Titel kon niet worden geopend")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView("Titel openen…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task { await resolve() }
    }

    private func resolve() async {
        guard let tmdbID, tmdbID > 0 else { failed = true; return }
        do {
            if kind == .movie {
                guard let service = TMDBService() else { failed = true; return }
                let resolved = try await service.mediaItem(forMovieID: tmdbID)
                try Task.checkCancellation()
                movie = resolved
            } else {
                guard let service = SeriesService() else { failed = true; return }
                let details = try await service.seriesDetails(id: tmdbID)
                try Task.checkCancellation()
                series = TMDBSeries(
                    id: tmdbID, name: details.name, overview: details.overview,
                    posterPath: details.posterPath, backdropPath: details.backdropPath,
                    firstAirDate: details.firstAirDate, voteAverage: details.voteAverage, genreIDs: nil)
            }
        } catch is CancellationError {
            return
        } catch {
            failed = true
        }
    }
}
