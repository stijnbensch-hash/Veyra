// VeyraBentoModel.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// Gegevenslaag voor de bento-home. Combineert wat er al is:
//   Verder kijken + Vandaag  <- VeyraHomeViewModel (Trakt)
//   Live nu + Tijd voor jou  <- EPG-zenders (VeyraBentoEPGModel.swift)
//   Nieuw toegevoegd         <- RecentlyAddedProviding (Veyra Hub / bibliotheek)
//   Bronnen                  <- SourceStatusProviding (Veyra Hub · AIOStreams · IPTV)
// Elke bron is optioneel: een tegel zonder data verdwijnt uit de home in plaats van leeg te staan.
// Vereist: VeyraBentoTrakt.swift, VeyraBentoEPGModel.swift, VeyraBentoHeroModel.swift.

import Foundation
import Observation

// MARK: - Modellen

nonisolated struct BentoLiveRow: Identifiable, Equatable {
    let id: String               // EPGProgram.id
    let channelID: String
    let channelNumber: Int
    let channelName: String
    let title: String
    let remainingMinutes: Int
    let progress: Double
    let isSports: Bool
    let health: SourceHealth
    var logoURL: URL? = nil
}

nonisolated struct BentoToday: Equatable {
    let heading: String          // "Vandaag" · "Binnenkort" als er vandaag niets is
    let subheading: String       // "wo 23 sep · Trakt"
    let items: [UpcomingItem]
}

nonisolated struct BentoNewItem: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let kind: MediaKind
    var posterURL: URL? = nil
}

nonisolated struct BentoSource: Identifiable, Equatable, Sendable {
    let id: String
    let name: String             // "Veyra Hub", "AIOStreams", "IPTV"
    let health: SourceHealth
}

nonisolated struct BentoTimeSuggestion: Identifiable, Equatable {
    enum Target: Equatable {
        case resume(ContinueItem)
        case live(channelID: String, programID: String)
    }
    let id: String
    let title: String
    let detail: String           // "S4E2" · "Eén"
    let minutes: Int
    let target: Target
}

// MARK: - Bronnen

nonisolated protocol RecentlyAddedProviding: Sendable {
    func recentlyAdded(limit: Int) async throws -> [BentoNewItem]
}

nonisolated protocol SourceStatusProviding: Sendable {
    func sources() async -> [BentoSource]
}

// MARK: - ViewModel

@MainActor
@Observable
final class VeyraBentoViewModel {
    /// Trakt-model: hiermee delen de bento-home en andere schermen dezelfde data.
    let home: VeyraHomeViewModel

    private(set) var channels: [EPGChannel] = []
    private(set) var newItems: [BentoNewItem] = []
    private(set) var sources: [BentoSource] = []
    private(set) var iptvFilms: [IPTVVODItem] = []
    private(set) var iptvSeries: [XtreamSeriesItem] = []
    private(set) var releaseFilms: [BentoTMDBTitle] = []
    private(set) var releaseSeries: [BentoTMDBTitle] = []
    private(set) var providers: [BentoCatalog] = []
    private(set) var collections: [BentoCatalog] = []
    /// Hoeveel tijd de kijker heeft. Standaard 40 min; koppel aan een pickertje of aan de agenda.
    var availableMinutes: Int

    @ObservationIgnored private let epg: (@Sendable () async -> [EPGChannel])?
    @ObservationIgnored private let added: (any RecentlyAddedProviding)?
    @ObservationIgnored private let status: (any SourceStatusProviding)?
    @ObservationIgnored private let filmsSource: (@Sendable () async -> [IPTVVODItem])?
    @ObservationIgnored private let seriesSource: (@Sendable () async -> [XtreamSeriesItem])?
    @ObservationIgnored private let releaseFilmsSource: (@Sendable () async -> [BentoTMDBTitle])?
    @ObservationIgnored private let releaseSeriesSource: (@Sendable () async -> [BentoTMDBTitle])?
    @ObservationIgnored private let providersSource: (@Sendable () async -> [BentoCatalog])?
    @ObservationIgnored private let collectionsSource: (@Sendable () async -> [BentoCatalog])?

    init(home: VeyraHomeViewModel,
         epg: (@Sendable () async -> [EPGChannel])? = nil,
         recentlyAdded: (any RecentlyAddedProviding)? = nil,
         sourceStatus: (any SourceStatusProviding)? = nil,
         iptvFilms: (@Sendable () async -> [IPTVVODItem])? = nil,
         iptvSeries: (@Sendable () async -> [XtreamSeriesItem])? = nil,
         releasesFilms: (@Sendable () async -> [BentoTMDBTitle])? = nil,
         releasesSeries: (@Sendable () async -> [BentoTMDBTitle])? = nil,
         streaming: (@Sendable () async -> [BentoCatalog])? = nil,
         collections: (@Sendable () async -> [BentoCatalog])? = nil,
         availableMinutes: Int = 40) {
        self.home = home
        self.epg = epg
        self.added = recentlyAdded
        self.status = sourceStatus
        self.filmsSource = iptvFilms
        self.seriesSource = iptvSeries
        self.releaseFilmsSource = releasesFilms
        self.releaseSeriesSource = releasesSeries
        self.providersSource = streaming
        self.collectionsSource = collections
        self.availableMinutes = availableMinutes
    }

    // MARK: Laden

    nonisolated private static func fetchChannels(_ source: (@Sendable () async -> [EPGChannel])?) async -> [EPGChannel] {
        guard let source else { return [] }
        return await source()
    }

    nonisolated private static func fetchNew(_ provider: (any RecentlyAddedProviding)?) async -> [BentoNewItem] {
        guard let provider else { return [] }
        do { return try await provider.recentlyAdded(limit: 10) } catch { return [] }
    }

    nonisolated private static func fetchSources(_ provider: (any SourceStatusProviding)?) async -> [BentoSource] {
        guard let provider else { return [] }
        return await provider.sources()
    }

    @ObservationIgnored private var lastLoad: Date?

    /// `force: false` slaat over als er net geladen is (terugkeren naar Home mag niet elke keer alles opnieuw ophalen).
    func load(force: Bool = false) async {
        if !force, let lastLoad, Date().timeIntervalSince(lastLoad) < 45, home.phase == .loaded {
            // Goedkoop en altijd actueel: IPTV-lijsten opnieuw filteren op de zichtbaarheidsinstellingen,
            // en de filmcollecties opnieuw lezen (kan net in Instellingen aangepast zijn).
            if let films = self.filmsSource { iptvFilms = await films() }
            if let series = self.seriesSource { iptvSeries = await series() }
            if let collections = self.collectionsSource {
                let items = await collections()
                if !items.isEmpty || VeyraCollectionsStore.load() != nil { self.collections = items }
            }
            if let streaming = self.providersSource {
                let items = await streaming()
                if !items.isEmpty || VeyraStreamingStore.load() != nil { self.providers = items }
            }
            return
        }
        lastLoad = Date()
        let epg = self.epg, added = self.added, status = self.status
        let filmsSource = self.filmsSource, seriesSource = self.seriesSource
        let releaseFilmsSource = self.releaseFilmsSource, releaseSeriesSource = self.releaseSeriesSource
        let providersSource = self.providersSource, collectionsSource = self.collectionsSource
        // Elke bron vult zijn eigen tegel zodra hij klaar is; een trage EPG houdt Verder kijken niet tegen.
        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in await self.home.load() }
            group.addTask { @MainActor in
                let c = await Self.fetchChannels(epg)
                if epg != nil { self.channels = c }
            }
            group.addTask { @MainActor in
                let n = await Self.fetchNew(added)
                self.newItems = n
            }
            group.addTask { @MainActor in
                let s = await Self.fetchSources(status)
                self.sources = s
            }
            if let filmsSource {
                group.addTask { @MainActor in
                    let films = await filmsSource()
                    self.iptvFilms = films
                }
            }
            if let releaseFilmsSource {
                group.addTask { @MainActor in
                    let items = await releaseFilmsSource()
                    self.releaseFilms = items
                }
            }
            if let releaseSeriesSource {
                group.addTask { @MainActor in
                    let items = await releaseSeriesSource()
                    self.releaseSeries = items
                }
            }
            if let providersSource {
                group.addTask { @MainActor in
                    let items = await providersSource()
                    if !items.isEmpty || VeyraStreamingStore.load() != nil { self.providers = items }
                }
            }
            if let collectionsSource {
                group.addTask { @MainActor in
                    let items = await collectionsSource()
                    if !items.isEmpty || VeyraCollectionsStore.load() != nil { self.collections = items }
                }
            }
            if let seriesSource {
                group.addTask { @MainActor in
                    let series = await seriesSource()
                    self.iptvSeries = series
                }
            }
        }
    }

    /// Goedkope verversing (elke paar minuten): alleen EPG + bronnen.
    func refreshLive() async {
        let epg = self.epg, status = self.status
        async let liveChannels = Self.fetchChannels(epg)
        async let health = Self.fetchSources(status)
        let (c, s) = await (liveChannels, health)
        if epg != nil { channels = c }
        if status != nil { sources = s }
    }

    // MARK: Verder kijken

    var continueMain: ContinueItem? { home.continueItems.first }
    var continueAlso: ContinueItem? { home.continueItems.dropFirst().first }

    // MARK: Live nu

    private static func rank(_ health: SourceHealth) -> Int {
        switch health { case .good: return 0; case .degraded: return 1; case .down: return 2 }
    }

    /// Maximaal `limit` zenders die nu iets uitzenden: één live sportwedstrijd, dan favorieten, dan de rest.
    func liveRows(at now: Date, limit: Int = 3, recentFirst: Bool = false) -> [BentoLiveRow] {
        let live = channels.compactMap { channel -> (EPGChannel, EPGProgram)? in
            guard channel.health != .down, let program = channel.currentProgram(at: now) else { return nil }
            return (channel, program)
        }

        var picked: [(EPGChannel, EPGProgram)] = []
        func add(_ pair: (EPGChannel, EPGProgram)) {
            if picked.count < limit, !picked.contains(where: { $0.0.id == pair.0.id }) { picked.append(pair) }
        }

        if recentFirst {
            // Laatst bekeken zenders eerst (nieuwste bovenaan); daarna pas de gewone selectie als er te weinig zijn.
            live.filter { $0.0.recentRank != nil }
                .sorted { ($0.0.recentRank ?? .max) < ($1.0.recentRank ?? .max) }
                .forEach(add)
        } else if let sport = live.filter({ $0.1.isSports }).min(by: {
            (Self.rank($0.0.health), $0.0.number) < (Self.rank($1.0.health), $1.0.number)
        }) { add(sport) }
        live.filter { $0.0.isFavorite }.sorted { $0.0.number < $1.0.number }.forEach(add)
        live.sorted { $0.0.number < $1.0.number }.forEach(add)

        let ordered = recentFirst && picked.contains(where: { $0.0.recentRank != nil })
            ? picked
            : picked.sorted { $0.0.number < $1.0.number }
        return ordered.map { channel, program in
            BentoLiveRow(
                id: program.id, channelID: channel.id, channelNumber: channel.number, channelName: channel.name,
                title: program.title,
                remainingMinutes: max(1, Int((program.end.timeIntervalSince(now) / 60).rounded(.up))),
                progress: program.progress(at: now) ?? 0,
                isSports: program.isSports, health: channel.health, logoURL: channel.logoURL)
        }
    }

    /// De rij die de hero krijgt als de focus op "Live nu" staat: sport eerst.
    func featuredLiveRow(at now: Date) -> BentoLiveRow? {
        let rows = liveRows(at: now)
        return rows.first { $0.isSports } ?? rows.first
    }

    // MARK: Vandaag

    /// "Binnenkort": de eerstvolgende releases uit de Trakt-kalender, met datum en resterende tijd in de rij zelf.
    func today(at now: Date, limit: Int = 4, calendar: Calendar = .current) -> BentoToday? {
        let startOfToday = calendar.startOfDay(for: now)
        let coming = home.upcoming
            .filter { $0.isDateOnly ? $0.airDate >= startOfToday : $0.airDate >= now.addingTimeInterval(-3600) }
            .sorted { $0.airDate < $1.airDate }
        guard !coming.isEmpty else { return nil }
        return BentoToday(heading: "Binnenkort", subheading: "", items: Array(coming.prefix(limit)))
    }

    // MARK: Tijd voor jou

    func timeSuggestions(at now: Date, limit: Int = 2) -> [BentoTimeSuggestion] {
        let budget = availableMinutes
        var out: [BentoTimeSuggestion] = []

        // 1. Iets dat je in deze tijd afkijkt.
        let finishable = home.continueItems
            .filter { ($0.remainingMinutes ?? Int.max) <= budget + 5 && !$0.isUpNext }
            .sorted { ($0.remainingMinutes ?? 0) > ($1.remainingMinutes ?? 0) }
        for item in finishable.prefix(limit) {
            out.append(BentoTimeSuggestion(
                id: "resume-\(item.id)", title: item.title, detail: item.episodeCode ?? "Film",
                minutes: item.remainingMinutes ?? budget, target: .resume(item)))
        }

        // 1b. Een volgende aflevering die in de tijd past.
        if out.count < limit {
            let next = home.continueItems
                .filter { $0.isUpNext && ($0.remainingMinutes ?? Int.max) <= budget + 5 }
                .sorted { ($0.remainingMinutes ?? 0) > ($1.remainingMinutes ?? 0) }
            for item in next.prefix(limit - out.count) {
                out.append(BentoTimeSuggestion(
                    id: "next-\(item.id)", title: item.title, detail: item.episodeCode ?? "Aflevering",
                    minutes: item.remainingMinutes ?? budget, target: .resume(item)))
            }
        }

        // 2. Iets van de watchlist dat nu bezig is of zo begint en in de tijd past.
        if out.count < limit {
            let horizon = now.addingTimeInterval(15 * 60)
            let live = channels.filter { $0.health != .down }.compactMap { channel -> BentoTimeSuggestion? in
                guard let program = channel.programs.first(where: { $0.isInWatchlist && $0.end > now && $0.start <= horizon }) else { return nil }
                let minutes = program.isLive(at: now)
                    ? max(1, Int((program.end.timeIntervalSince(now) / 60).rounded(.up)))
                    : program.durationMinutes
                guard minutes <= budget + 5 else { return nil }
                return BentoTimeSuggestion(id: "live-\(program.id)", title: program.title, detail: channel.name,
                                           minutes: minutes, target: .live(channelID: channel.id, programID: program.id))
            }
            out.append(contentsOf: live.prefix(limit - out.count))
        }

        // 3. Iets dat nu live loopt en binnen de tijd afgelopen is.
        if out.count < limit {
            let finishing = channels.filter { $0.health != .down }.compactMap { channel -> BentoTimeSuggestion? in
                guard let program = channel.currentProgram(at: now) else { return nil }
                let minutes = max(1, Int((program.end.timeIntervalSince(now) / 60).rounded(.up)))
                guard minutes <= budget + 5, !out.contains(where: { $0.id == "live-\(program.id)" }) else { return nil }
                return BentoTimeSuggestion(id: "live-\(program.id)", title: program.title, detail: channel.name,
                                           minutes: minutes, target: .live(channelID: channel.id, programID: program.id))
            }
            out.append(contentsOf: finishing.prefix(limit - out.count))
        }
        return out
    }

    // MARK: Bronnen

    var sourceSummary: (good: Int, total: Int, degraded: Int, down: Int) {
        (sources.filter { $0.health == .good }.count, sources.count,
         sources.filter { $0.health == .degraded }.count, sources.filter { $0.health == .down }.count)
    }

    // MARK: Hero-mapping

    func heroContent(forLive row: BentoLiveRow, now: Date = .now) -> HeroContent? {
        guard let channel = channels.first(where: { $0.id == row.channelID }),
              let program = channel.currentProgram(at: now) else { return nil }
        var moments = [program.heroMoment(at: now, health: channel.health)]
        if let next = channel.nextProgram(after: program.end) {
            moments.append(next.heroMoment(at: now, health: channel.health))
        }
        return HeroContent(logoURL: nil, fallbackTitle: program.title, moments: moments)
    }
}

// MARK: - Voorbeelddata (previews)

#if DEBUG
nonisolated struct MockRecentlyAdded: RecentlyAddedProviding {
    func recentlyAdded(limit: Int) async throws -> [BentoNewItem] {
        ["Dune", "The Bear", "Andor", "Shōgun", "Fallout", "Slow Horses"].enumerated().map {
            BentoNewItem(id: "n\($0.offset)", title: $0.element, kind: .movie)
        }
    }
}

nonisolated struct MockSourceStatus: SourceStatusProviding {
    func sources() async -> [BentoSource] {
        [BentoSource(id: "hub", name: "Veyra Hub", health: .good),
         BentoSource(id: "aio", name: "AIOStreams", health: .good),
         BentoSource(id: "iptv", name: "IPTV", health: .degraded)]
    }
}

extension VeyraBentoViewModel {
    static func preview() -> VeyraBentoViewModel {
        let now = Date()
        func program(_ id: String, _ title: String, start: Double, minutes: Double, sports: Bool = false) -> EPGProgram {
            EPGProgram(id: id, title: title, subtitle: nil, description: nil,
                       start: now.addingTimeInterval(start * 60), end: now.addingTimeInterval((start + minutes) * 60),
                       backdropURL: nil, isSports: sports, isInWatchlist: false, canCatchUp: sports)
        }
        let channels = [
            EPGChannel(id: "een", number: 1, name: "Eén", logoURL: nil, health: .good, isFavorite: true,
                       programs: [program("p1", "Het Journaal", start: -48, minutes: 60), program("p1b", "Terzake", start: 12, minutes: 40)]),
            EPGChannel(id: "sport1", number: 11, name: "Play Sports 1", logoURL: nil, health: .degraded, isFavorite: false,
                       programs: [program("p2", "Club Brugge – Anderlecht", start: -63, minutes: 110, sports: true)]),
            EPGChannel(id: "vtm", number: 3, name: "VTM", logoURL: nil, health: .good, isFavorite: false,
                       programs: [program("p3", "The Voice", start: -56, minutes: 90)])
        ]
        return VeyraBentoViewModel(
            home: VeyraHomeViewModel(provider: MockTraktHomeProvider()),
            epg: { channels },
            recentlyAdded: MockRecentlyAdded(),
            sourceStatus: MockSourceStatus())
    }
}
#endif
