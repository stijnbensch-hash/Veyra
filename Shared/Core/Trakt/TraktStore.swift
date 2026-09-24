import Foundation
import Combine

@MainActor
final class TraktStore: ObservableObject {
    static let shared = TraktStore()

    let client: TraktClient

    @Published private(set) var isConnected = false
    @Published private(set) var isSyncing = false

    @Published private(set) var user: TraktUser?

    @Published private(set) var watchlist: [TraktEntry] = []
    @Published private(set) var playback: [TraktEntry] = []

    @Published private(set) var upNext: [TraktUpNext] = []

    // Home gebruikt deze lijst ook voordat de live Trakt-sync klaar is.
    @Published private(set) var cachedUpNextEntries: [TraktEntry] = []

    @Published private(set) var history: [TraktEntry] = []
    @Published private(set) var ratings: [TraktEntry] = []
    @Published private(set) var lists: [TraktList] = []

    @Published private(set) var watchedMovies: [TraktEntry] = []
    @Published private(set) var watchedShows: [TraktEntry] = []

    @Published private(set) var lastWatchedSync: Date?
    @Published private(set) var lastSync: Date?

    @Published var errorMessage: String?

    @Published var scrobblingEnabled: Bool {
        didSet {
            preferences.set(
                scrobblingEnabled,
                forKey: "trakt.scrobbling"
            )
        }
    }

    private let preferences: UserDefaults

    private var refreshTask: Task<Void, Never>?
    private var refreshID = UUID()
    private var revision = UUID()
    private var scrobbleTail: Task<Void, Never>?

    private static let homeCacheKey =
        "veyra.trakt.home.cache.v1"

    var isConfigured: Bool {
        client.isConfigured
    }

    init(
        client: TraktClient? = nil,
        preferences: UserDefaults = .standard
    ) {
        self.preferences = preferences

        let client =
            client ?? TraktClient()

        self.client = client

        isConnected =
            client.isAuthenticated

        scrobblingEnabled =
            preferences.bool(
                forKey: "trakt.scrobbling"
            )

        errorMessage =
            client.restorationError?
                .localizedDescription

        // Cache eerst tonen.
        // Geen netwerk nodig.
        if isConnected {
            restoreHomeCache()
        }
    }

    // MARK: - Connection

    func connected() async {
        revision = UUID()

        scrobblingEnabled = false

        clearCachedData(
            removePersistentHomeCache: true
        )

        isConnected =
            client.isAuthenticated

        await refresh()
    }

    func disconnect() async {
        revision = UUID()

        refreshTask?.cancel()
        refreshTask = nil

        isSyncing = false

        scrobbleTail?.cancel()
        scrobbleTail = nil

        scrobblingEnabled = false

        do {
            try await client.disconnect()
        } catch {
            errorMessage =
                client.isAuthenticated
                ? error.localizedDescription
                : """
                  Lokaal ontkoppeld. Intrekken bij Trakt is niet bevestigd; \
                  verwijder Veyra zo nodig ook bij je Trakt-apps.
                  """
        }

        isConnected =
            client.isAuthenticated

        if !isConnected {
            clearCachedData(
                removePersistentHomeCache: true
            )
        }
    }

    // MARK: - Refresh

    func refreshIfNeeded() async {
        guard
            lastSync == nil
                || Date()
                    .timeIntervalSince(
                        lastSync!
                    ) > 60
        else {
            return
        }

        await refresh()
    }

    func refresh() async {
        if let refreshTask {
            await refreshTask.value
            return
        }

        guard isConnected else {
            return
        }

        let snapshot =
            revision

        let id =
            UUID()

        refreshID = id

        let task =
            Task {
                await self.loadSnapshot()
            }

        refreshTask = task

        await task.value

        if snapshot == revision,
           refreshID == id
        {
            refreshTask = nil
        }
    }

    private func refreshAfterMutation() async {
        // Een lopende GET kan ouder zijn dan de mutatie.
        // Eerst laten eindigen en daarna opnieuw ophalen.
        let id =
            refreshID

        if let refreshTask {
            await refreshTask.value
        }

        if refreshID == id {
            refreshTask = nil
        }

        await refresh()
    }

    // MARK: - Full snapshot

    private func loadSnapshot() async {
        guard isConnected else {
            return
        }

        isSyncing = true
        errorMessage = nil

        let snapshot =
            revision

        defer {
            if snapshot == revision {
                isSyncing = false
            }
        }

        // Watched-state staat los van de overige bibliotheek.
        await loadWatchedSnapshot(
            snapshot: snapshot
        )

        guard
            snapshot == revision,
            isConnected,
            !Task.isCancelled
        else {
            return
        }

        do {
            let settings:
                TraktSettings =
                try await client.request(
                    "users/settings"
                )

            let movies:
                [TraktEntry] =
                try await client.allPages(
                    "sync/watchlist/movies/added/desc"
                )

            let shows:
                [TraktEntry] =
                try await client.allPages(
                    "sync/watchlist/shows/added/desc"
                )

            let episodes:
                [TraktEntry] =
                try await client.allPages(
                    "sync/watchlist/episodes/added/desc"
                )

            let movieProgress:
                [TraktEntry] =
                try await client.allPages(
                    "sync/playback/movies"
                )

            let episodeProgress:
                [TraktEntry] =
                try await client.allPages(
                    "sync/playback/episodes"
                )

            let movieRatings:
                [TraktEntry] =
                try await client.allPages(
                    "users/me/ratings/movies"
                )

            let showRatings:
                [TraktEntry] =
                try await client.allPages(
                    "users/me/ratings/shows"
                )

            let episodeRatings:
                [TraktEntry] =
                try await client.allPages(
                    "users/me/ratings/episodes"
                )

            let personalLists:
                [TraktList] =
                try await client.allPages(
                    "users/me/lists"
                )

            let nextEpisodes:
                [TraktUpNext] =
                try await client.allPages(
                    "sync/progress/up_next"
                )

            let recentHistory:
                [TraktEntry] =
                try await client.request(
                    "users/me/history?page=1&limit=100"
                )

            guard
                snapshot == revision
            else {
                return
            }

            user =
                settings.user

            watchlist =
                movies
                + shows
                + episodes

            playback =
                (
                    movieProgress
                    + episodeProgress
                )
                .sorted {
                    ($0.pausedAt ?? "")
                        >
                    ($1.pausedAt ?? "")
                }

            ratings =
                movieRatings
                + showRatings
                + episodeRatings

            lists =
                personalLists

            history =
                recentHistory

            upNext =
                nextEpisodes

            cachedUpNextEntries =
                nextEpisodes
                    .compactMap(\.entry)

            lastSync =
                Date()

            // Nieuwe serverdata direct lokaal bewaren.
            saveHomeCache()

        } catch is CancellationError {
            return

        } catch {
            guard
                snapshot == revision
            else {
                return
            }

            // Als Trakt tijdelijk faalt blijft de reeds
            // geladen Home-cache gewoon zichtbaar.
            report(error)
        }
    }

    // MARK: - Watched snapshot

    private func loadWatchedSnapshot(
        snapshot: UUID
    ) async {
        var succeeded = true

        do {
            let values:
                [TraktEntry] =
                try await client.allPages(
                    "sync/watched/movies"
                )

            guard
                snapshot == revision,
                !Task.isCancelled
            else {
                return
            }

            watchedMovies =
                values

        } catch is CancellationError {
            return

        } catch {
            guard
                snapshot == revision
            else {
                return
            }

            succeeded = false
            report(error)
        }

        guard
            snapshot == revision,
            isConnected,
            !Task.isCancelled
        else {
            return
        }

        do {
            let values:
                [TraktEntry] =
                try await client.allPages(
                    "sync/watched/shows?extended=progress"
                )

            guard
                snapshot == revision,
                !Task.isCancelled
            else {
                return
            }

            watchedShows =
                values

        } catch is CancellationError {
            return

        } catch {
            guard
                snapshot == revision
            else {
                return
            }

            succeeded = false
            report(error)
        }

        if succeeded,
           snapshot == revision
        {
            lastWatchedSync =
                Date()
        }
    }

    // MARK: - Home cache

    private func restoreHomeCache() {
        // Sinds kort staat deze cache in een los bestand op schijf i.p.v.
        // UserDefaults — een grote (2000+ bekeken titels) cache in
        // UserDefaults/CFPreferences kan op tvOS de hele app laten
        // crashen zodra de totale opslag daar over ~1 MB gaat (zie ook
        // VeyraEPGStore en VeyraHubSyncService). `IPTVDiskCache` kent die
        // limiet niet.
        if let cache = IPTVDiskCache.read(TraktHomeCache.self, key: Self.homeCacheKey)?.value {
            applyHomeCache(cache)
            return
        }

        // Eenmalige migratie van een oudere, nog in UserDefaults staande
        // cache: overnemen, naar schijf schrijven en de oude sleutel
        // meteen opruimen zodat die niet blijft meetellen voor de
        // CFPreferences-limiet.
        guard
            let data = preferences.data(forKey: Self.homeCacheKey),
            let cache = try? JSONDecoder().decode(TraktHomeCache.self, from: data)
        else {
            preferences.removeObject(forKey: Self.homeCacheKey)
            return
        }

        preferences.removeObject(forKey: Self.homeCacheKey)
        applyHomeCache(cache)
        IPTVDiskCache.write(cache, key: Self.homeCacheKey)
    }

    private func applyHomeCache(_ cache: TraktHomeCache) {
        playback =
            cache.playback
                .sorted {
                    ($0.pausedAt ?? "")
                        >
                    ($1.pausedAt ?? "")
                }

        cachedUpNextEntries =
            cache.upNextEntries

        watchedMovies =
            cache.watchedMovies

        watchedShows =
            cache.watchedShows

        // Belangrijk:
        // lastSync/lastWatchedSync NIET herstellen.
        //
        // Daardoor tonen Home en de bekeken-badges eerst de cache
        // en start daarna alsnog een actuele
        // Trakt-sync op de achtergrond.
        lastSync = nil
        lastWatchedSync = nil
    }

    private func saveHomeCache() {
        let cache =
            TraktHomeCache(
                playback:
                    Array(
                        playback.prefix(100)
                    ),
                upNextEntries:
                    Array(
                        cachedUpNextEntries
                            .prefix(100)
                    ),
                watchedMovies:
                    Array(
                        watchedMovies.prefix(2000)
                    ),
                watchedShows:
                    Array(
                        watchedShows.prefix(2000)
                    )
            )

        IPTVDiskCache.write(cache, key: Self.homeCacheKey)
    }

    private func removeHomeCache() {
        IPTVDiskCache.remove(key: Self.homeCacheKey)

        // Eventuele oude kopie uit UserDefaults ook opruimen.
        preferences.removeObject(
            forKey:
                Self.homeCacheKey
        )
    }

    // MARK: - Errors / reset

    private func report(
        _ error: Error
    ) {
        isConnected =
            client.isAuthenticated

        if !isConnected {
            clearCachedData(
                removePersistentHomeCache:
                    true
            )
        }

        errorMessage =
            error.localizedDescription
    }

    private func clearCachedData(
        removePersistentHomeCache:
            Bool = false
    ) {
        user = nil

        watchlist = []
        playback = []

        upNext = []
        cachedUpNextEntries = []

        history = []
        ratings = []
        lists = []

        watchedMovies = []
        watchedShows = []

        lastWatchedSync = nil
        lastSync = nil

        if removePersistentHomeCache {
            removeHomeCache()
        }
    }

    // MARK: - Queries

    func isWatchlisted(
        _ item: MediaItem
    ) -> Bool {
        watchlist.contains {
            $0.matches(item)
        }
    }

    func rating(
        for item: MediaItem
    ) -> Int? {
        ratings.first {
            $0.matches(item)
        }?.rating
    }

    func progress(
        for item: MediaItem
    ) -> Double? {
        guard
            let value =
                playback.first(
                    where: {
                        $0.matches(item)
                    }
                )?.progress,
            value.isFinite,
            value > 0,
            value < 100
        else {
            return nil
        }

        return value
    }

    func isWatched(
        _ item: MediaItem
    ) -> Bool {
        if item.type == .movie {
            return watchedMovies.contains {
                $0.matches(item)
            }
        }

        guard
            let season =
                item.seasonNumber,
            let episode =
                item.episodeNumber
        else {
            return false
        }

        return watchedShows.contains {
            entry in

            let matches =
                entry.show?
                    .ids
                    .matches(
                        TraktIDs(
                            imdb:
                                item.imdbID,
                            tmdb:
                                item.tmdbID
                        )
                    )
                ?? false

            return matches
                && (
                    entry.seasons?
                        .contains {
                            seasonValue in

                            seasonValue.number
                                == season
                                &&
                            seasonValue.episodes
                                .contains {
                                    episodeValue in

                                    episodeValue.number
                                        == episode
                                        &&
                                    (
                                        episodeValue.plays
                                        ?? 1
                                    ) > 0
                                }
                        }
                    ?? false
                )
        }
    }

    // MARK: - Mutations

    private func mutate(
        _ path: String,
        item: MediaItem,
        rating: Int? = nil
    ) async throws {
        guard
            item.canSyncTrakt
        else {
            throw TraktError
                .missingMedia
        }

        do {
            let response:
                TraktSyncResult =
                try await client.request(
                    path,
                    method: "POST",
                    body:
                        item.traktSyncBody(
                            rating: rating
                        )
                )

            if response.hasMissingItems {
                throw TraktError
                    .missingMedia
            }

        } catch {
            report(error)
            throw error
        }
    }

    func setWatchlist(
        _ item: MediaItem,
        included: Bool
    ) async throws {
        try await mutate(
            "sync/watchlist"
                + (
                    included
                    ? ""
                    : "/remove"
                ),
            item: item
        )

        await refreshAfterMutation()
    }

    func setWatched(
        _ item: MediaItem,
        watched: Bool
    ) async throws {
        // Geen tweede play toevoegen wanneer
        // dezelfde titel al bekeken is.
        if watched
            && isWatched(item)
        {
            return
        }

        try await mutate(
            "sync/history"
                + (
                    watched
                    ? ""
                    : "/remove"
                ),
            item: item
        )

        await refreshAfterMutation()
    }

    func setRating(
        _ item: MediaItem,
        rating: Int?
    ) async throws {
        if let rating,
           !(1...10)
            .contains(rating)
        {
            throw TraktError
                .invalidResponse
        }

        try await mutate(
            "sync/ratings"
                + (
                    rating == nil
                    ? "/remove"
                    : ""
                ),
            item: item,
            rating: rating
        )

        await refreshAfterMutation()
    }

    // MARK: - Lists

    func listItems(
        _ list: TraktList
    ) async throws -> [TraktEntry] {
        try await client.allPages(
            "users/me/lists/\(list.id)/items/movie,show,season,episode"
        )
    }

    func add(
        _ item: MediaItem,
        to list: TraktList
    ) async throws {
        try await mutate(
            "users/me/lists/\(list.id)/items",
            item: item
        )

        await refreshAfterMutation()
    }

    func remove(
        _ entry: TraktEntry,
        from list: TraktList
    ) async throws {
        guard
            let ids =
                entry.media?.ids
        else {
            throw TraktError
                .missingMedia
        }

        let data =
            try client.encoder
                .encode(ids)

        let object =
            try JSONSerialization
                .jsonObject(
                    with: data
                )

        let plural =
            entry.kind == "movie"
            ? "movies"
            : entry.kind == "show"
                ? "shows"
                : entry.kind == "season"
                    ? "seasons"
                    : "episodes"

        let result:
            TraktSyncResult =
            try await client.request(
                "users/me/lists/\(list.id)/items/remove",
                method: "POST",
                body: [
                    plural: [
                        [
                            "ids": object
                        ]
                    ]
                ]
            )

        if result.hasMissingItems {
            throw TraktError
                .missingMedia
        }
    }

    func createList(
        name: String
    ) async throws {
        let name =
            name.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        guard !name.isEmpty else {
            return
        }

        let _:
            TraktList =
            try await client.request(
                "users/me/lists",
                method: "POST",
                body: [
                    "name":
                        name,
                    "privacy":
                        "private",
                    "allow_comments":
                        false,
                    "display_numbers":
                        false
                ]
            )

        await refreshAfterMutation()
    }

    func renameList(
        _ list: TraktList,
        name: String
    ) async throws {
        let name =
            name.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        guard !name.isEmpty else {
            return
        }

        let _:
            TraktList =
            try await client.request(
                "users/me/lists/\(list.id)",
                method: "PUT",
                body: [
                    "name": name
                ]
            )

        await refreshAfterMutation()
    }

    func deleteList(
        _ list: TraktList
    ) async throws {
        try await client.delete(
            "users/me/lists/\(list.id)"
        )

        await refreshAfterMutation()
    }

    func historyPage(
        _ page: Int
    ) async throws -> [TraktEntry] {
        try await client.request(
            "users/me/history?page=\(page)&limit=100"
        )
    }

    // MARK: - Scrobbling

    /// Werkt `playback` (en de home-cache) meteen bij met de nieuwe
    /// positie, zonder te wachten op de Trakt-server. De echte
    /// scrobble-aanroep hierna zorgt voor de definitieve synchronisatie;
    /// dit zorgt er alleen voor dat "Verder kijken" nooit een wachttijd
    /// heeft na het pauzeren/stoppen van een film of aflevering.
    private func applyLocalProgress(
        item: MediaItem,
        action: String,
        progress: Double
    ) {
        guard action == "pause" || action == "stop" else {
            return
        }

        let pausedAt =
            ISO8601DateFormatter().string(from: Date())

        if progress >= 80 {
            // Trakt beschouwt dit als bekeken; verdwijnt uit "verder kijken".
            playback.removeAll {
                $0.matches(item)
            }

            // Alleen een echte stop (niet enkel pauzeren vlak voor het
            // einde) telt bij Trakt ook als "bekeken" in de
            // kijkgeschiedenis -- dat lokaal meteen mee bijwerken, anders
            // duurt het tot de volgende volledige sync voor het
            // "bekeken"-vinkje verschijnt.
            if action == "stop" {
                markWatchedLocally(item)
            }
        } else if let index = playback.firstIndex(where: {
            $0.matches(item)
        }) {
            playback[index].progress = progress
            playback[index].pausedAt = pausedAt
        } else {
            playback.append(
                makeLocalEntry(
                    for: item,
                    progress: progress,
                    pausedAt: pausedAt
                )
            )
        }

        saveHomeCache()
    }

    /// Zet een net afgespeeld item lokaal meteen op "bekeken", in het
    /// juiste formaat voor `isWatched(_:)`/`TraktWatchedStatus.resolve` --
    /// voor films een los entry, voor afleveringen de genest-per-seizoen
    /// vorm die de Trakt "watched shows"-sync gebruikt (`seasons`), niet de
    /// platte `show`+`episode`-vorm van `makeLocalEntry` (die is voor
    /// geschiedenis-/afspeel-entries, geen "bekeken"-overzicht).
    private func markWatchedLocally(_ item: MediaItem) {
        guard !isWatched(item) else { return }

        if item.type == .movie {
            watchedMovies.append(makeLocalEntry(for: item, progress: 100, pausedAt: ISO8601DateFormatter().string(from: Date())))
            saveHomeCache()
            return
        }

        guard let season = item.seasonNumber, let episode = item.episodeNumber else { return }
        let ids = TraktIDs(imdb: item.imdbID, tmdb: item.tmdbID)

        if let index = watchedShows.firstIndex(where: { $0.show?.ids.matches(ids) ?? false }) {
            var seasons = watchedShows[index].seasons ?? []
            if let seasonIndex = seasons.firstIndex(where: { $0.number == season }) {
                if !seasons[seasonIndex].episodes.contains(where: { $0.number == episode }) {
                    seasons[seasonIndex].episodes.append(TraktWatchedEpisode(number: episode, plays: 1))
                }
            } else {
                seasons.append(TraktWatchedSeason(number: season, episodes: [TraktWatchedEpisode(number: episode, plays: 1)]))
            }
            watchedShows[index].seasons = seasons
        } else {
            let show = TraktMedia(title: item.title, year: nil, ids: ids, season: nil, number: nil, overview: nil)
            watchedShows.append(TraktEntry(
                id: nil, rank: nil, type: "episode", movie: nil, show: show, episode: nil, season: nil,
                progress: 100, rating: nil, watchedAt: nil, pausedAt: nil, plays: nil,
                seasons: [TraktWatchedSeason(number: season, episodes: [TraktWatchedEpisode(number: episode, plays: 1)])]
            ))
        }
        saveHomeCache()
    }

    private func makeLocalEntry(
        for item: MediaItem,
        progress: Double,
        pausedAt: String
    ) -> TraktEntry {
        var movie: TraktMedia?
        var show: TraktMedia?
        var episode: TraktMedia?

        if item.traktKind == "episode" {
            show = TraktMedia(
                title: item.title,
                year: nil,
                ids: TraktIDs(
                    imdb: item.imdbID,
                    tmdb: item.tmdbID
                ),
                season: nil,
                number: nil,
                overview: nil
            )

            episode = TraktMedia(
                title: nil,
                year: nil,
                ids: TraktIDs(
                    tmdb: item.episodeTMDBID
                ),
                season: item.seasonNumber,
                number: item.episodeNumber,
                overview: item.overview
            )
        } else {
            movie = TraktMedia(
                title: item.title,
                year: nil,
                ids: TraktIDs(
                    imdb: item.imdbID,
                    tmdb: item.tmdbID
                ),
                season: nil,
                number: nil,
                overview: item.overview
            )
        }

        return TraktEntry(
            id: nil,
            rank: nil,
            type: item.traktKind,
            movie: movie,
            show: show,
            episode: episode,
            season: nil,
            progress: progress,
            rating: nil,
            watchedAt: nil,
            pausedAt: pausedAt,
            plays: nil,
            seasons: nil
        )
    }

    /// Serialize start/pause/stop.
    ///
    /// Een mislukte history-mutatie wordt niet
    /// automatisch opnieuw verstuurd, omdat een
    /// timeout kan betekenen dat Trakt hem reeds
    /// verwerkt heeft.
    func scrobble(
        _ action: String,
        item: MediaItem,
        progress: Double
    ) {
        guard
            isConnected,
            scrobblingEnabled,
            item.canSyncTrakt,
            item.traktKind != "show",
            progress.isFinite
        else {
            print("[TraktScrobble] \(action) GEBLOKKEERD door guard: isConnected=\(isConnected) scrobblingEnabled=\(scrobblingEnabled) canSyncTrakt=\(item.canSyncTrakt) traktKind=\(item.traktKind) progress=\(progress) tmdb=\(item.traktIDs.tmdb ?? -1) imdb=\(item.traktIDs.imdb ?? "nil")")
            return
        }

        if action != "start",
           progress < 1
        {
            print("[TraktScrobble] \(action) GEBLOKKEERD: progress \(progress) < 1")
            return
        }

        print("[TraktScrobble] \(action) wordt verstuurd, item=\(item.title) progress=\(progress)")

        let boundedProgressForLocalUpdate =
            min(100, max(0, progress))

        // Meteen lokaal bijwerken zodat "Verder kijken" niet hoeft te
        // wachten op de netwerk-rondtrip naar Trakt.
        applyLocalProgress(
            item: item,
            action: action,
            progress: boundedProgressForLocalUpdate
        )

        let previous =
            scrobbleTail

        let snapshot =
            revision

        let boundedProgress =
            min(
                100,
                max(
                    0,
                    progress
                )
            )

        scrobbleTail =
            Task {
                [weak self] in

                await previous?.value

                guard
                    let self,
                    !Task.isCancelled,
                    self.revision
                        == snapshot,
                    self.isConnected,
                    self.scrobblingEnabled
                else {
                    return
                }

                do {
                    let _:
                        TraktScrobbleResult =
                        try await self.client
                            .request(
                                "scrobble/\(action)",
                                method: "POST",
                                body: [
                                    item.traktKind:
                                        item.traktObject(),
                                    "progress":
                                        boundedProgress
                                ]
                            )

                    print("[TraktScrobble] \(action) GELUKT voor \(item.title) progress=\(boundedProgress)")

                    if action == "stop" {
                        await self
                            .refreshAfterMutation()
                    }

                } catch TraktError
                    .http(
                        409,
                        _,
                        _
                    )
                {
                    print("[TraktScrobble] \(action) 409 (al verwerkt door Trakt) voor \(item.title)")
                    if action == "stop" {
                        await self
                            .refreshAfterMutation()
                    }

                } catch is CancellationError {
                    print("[TraktScrobble] \(action) GEANNULEERD (nieuwe scrobble kwam ertussen) voor \(item.title)")
                    return

                } catch {
                    print("[TraktScrobble] \(action) MISLUKT voor \(item.title): \(error)")
                    guard
                        self.revision
                            == snapshot
                    else {
                        return
                    }

                    self.isConnected =
                        self.client
                            .isAuthenticated

                    if !self.isConnected {
                        self.clearCachedData(
                            removePersistentHomeCache:
                                true
                        )
                    }

                    self.errorMessage =
                        "Kijkvoortgang niet bevestigd door Trakt. \(error.localizedDescription)"
                }
            }
    }
}

// MARK: - Home cache model

// `nonisolated`: dit bestand/target isoleert nieuwe types standaard naar
// de main actor, maar Decodable/Encodable-vereisten (ook de handgeschreven
// `init(from:)` hieronder) zijn niet-geïsoleerd — zonder deze modifier
// botst de main-actor-isolatie met die conformance en faalt de build met
// "Main actor-isolated conformance ... cannot satisfy conformance
// requirement". Zie ook `VeyraLiveCatalog`/`VeyraGuideSnapshot` in
// VeyraEPGStore.swift, die dezelfde `nonisolated` nodig hebben.
nonisolated private struct TraktHomeCache:
    Codable, Sendable
{
    let playback:
        [TraktEntry]

    let upNextEntries:
        [TraktEntry]

    // Bekeken-status (films/series) — apart van de "verder kijken"-cache
    // hierboven, zodat bekeken-badges (bv. bij seizoenen/afleveringen)
    // ook meteen tonen voordat de live Trakt-sync klaar is.
    var watchedMovies: [TraktEntry] = []
    var watchedShows: [TraktEntry] = []

    init(playback: [TraktEntry], upNextEntries: [TraktEntry], watchedMovies: [TraktEntry], watchedShows: [TraktEntry]) {
        self.playback = playback
        self.upNextEntries = upNextEntries
        self.watchedMovies = watchedMovies
        self.watchedShows = watchedShows
    }

    // Eigen decoding: watchedMovies/watchedShows zijn later toegevoegd.
    // Een oudere, al opgeslagen cache zonder die velden mag niet in zijn
    // geheel als "beschadigd" verworpen worden — anders verdwijnt ook de
    // bestaande "verder kijken"-cache (playback/upNextEntries) in één keer.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        playback = try container.decode([TraktEntry].self, forKey: .playback)
        upNextEntries = try container.decode([TraktEntry].self, forKey: .upNextEntries)
        watchedMovies = try container.decodeIfPresent([TraktEntry].self, forKey: .watchedMovies) ?? []
        watchedShows = try container.decodeIfPresent([TraktEntry].self, forKey: .watchedShows) ?? []
    }
}
