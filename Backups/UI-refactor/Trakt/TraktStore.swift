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
    @Published private(set) var history: [TraktEntry] = []
    @Published private(set) var ratings: [TraktEntry] = []
    @Published private(set) var lists: [TraktList] = []
    @Published private(set) var watchedMovies: [TraktEntry] = []
    @Published private(set) var watchedShows: [TraktEntry] = []
    @Published private(set) var lastSync: Date?
    @Published var errorMessage: String?
    @Published var scrobblingEnabled: Bool {
        didSet { preferences.set(scrobblingEnabled, forKey: "trakt.scrobbling") }
    }
    private let preferences: UserDefaults
    private var refreshTask: Task<Void, Never>?
    private var refreshID = UUID()
    private var revision = UUID()
    private var scrobbleTail: Task<Void, Never>?
    var isConfigured: Bool { client.isConfigured }

    init(client: TraktClient? = nil, preferences: UserDefaults = .standard) {
        self.preferences = preferences
        let client = client ?? TraktClient()
        self.client = client
        isConnected = client.isAuthenticated
        scrobblingEnabled = preferences.bool(forKey: "trakt.scrobbling")
        errorMessage = client.restorationError?.localizedDescription
    }

    func connected() async {
        revision = UUID()
        scrobblingEnabled = false
        clearCachedData()
        isConnected = client.isAuthenticated
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
        do { try await client.disconnect() }
        catch {
            errorMessage = client.isAuthenticated ? error.localizedDescription :
                "Lokaal ontkoppeld. Intrekken bij Trakt is niet bevestigd; verwijder Veyra zo nodig ook bij je Trakt-apps."
        }
        isConnected = client.isAuthenticated
        if !isConnected {
            clearCachedData()
        }
    }

    func refreshIfNeeded() async {
        guard lastSync == nil || Date().timeIntervalSince(lastSync!) > 60 else { return }
        await refresh()
    }

    func refresh() async {
        if let refreshTask { await refreshTask.value; return }
        guard isConnected else { return }
        let snapshot = revision
        let id = UUID()
        refreshID = id
        let task = Task { await self.loadSnapshot() }
        refreshTask = task
        await task.value
        if snapshot == revision && refreshID == id { refreshTask = nil }
    }

    private func refreshAfterMutation() async {
        // A GET already in flight may predate the mutation. Wait, then fetch a fresh snapshot.
        let id = refreshID
        if let refreshTask { await refreshTask.value }
        if refreshID == id { refreshTask = nil }
        await refresh()
    }

    private func loadSnapshot() async {
        guard isConnected else { return }
        isSyncing = true
        errorMessage = nil
        let snapshot = revision
        defer { if snapshot == revision { isSyncing = false } }
        do {
            let settings: TraktSettings = try await client.request("users/settings")
            let movies: [TraktEntry] = try await client.allPages("sync/watchlist/movies/added/desc")
            let shows: [TraktEntry] = try await client.allPages("sync/watchlist/shows/added/desc")
            let episodes: [TraktEntry] = try await client.allPages("sync/watchlist/episodes/added/desc")
            let movieProgress: [TraktEntry] = try await client.allPages("sync/playback/movies")
            let episodeProgress: [TraktEntry] = try await client.allPages("sync/playback/episodes")
            let watchedMovieValues: [TraktEntry] = try await client.request("sync/watched/movies")
            let watchedShowValues: [TraktEntry] = try await client.request("sync/watched/shows")
            let movieRatings: [TraktEntry] = try await client.allPages("users/me/ratings/movies")
            let showRatings: [TraktEntry] = try await client.allPages("users/me/ratings/shows")
            let episodeRatings: [TraktEntry] = try await client.allPages("users/me/ratings/episodes")
            let personalLists: [TraktList] = try await client.allPages("users/me/lists")
            let nextEpisodes: [TraktUpNext] = try await client.allPages("sync/progress/up_next")
            let recentHistory: [TraktEntry] = try await client.request("users/me/history?page=1&limit=100")
            guard snapshot == revision else { return }
            user = settings.user
            watchlist = movies + shows + episodes
            playback = (movieProgress + episodeProgress).sorted { ($0.pausedAt ?? "") > ($1.pausedAt ?? "") }
            watchedMovies = watchedMovieValues
            watchedShows = watchedShowValues
            ratings = movieRatings + showRatings + episodeRatings
            lists = personalLists
            history = recentHistory
            upNext = nextEpisodes
            lastSync = Date()
        } catch is CancellationError { }
        catch {
            guard snapshot == revision else { return }
            report(error)
        }
    }

    private func report(_ error: Error) {
        isConnected = client.isAuthenticated
        if !isConnected { clearCachedData() }
        errorMessage = error.localizedDescription
    }

    private func clearCachedData() {
        user = nil; watchlist = []; playback = []; history = []; ratings = []
        lists = []; upNext = []; watchedMovies = []; watchedShows = []; lastSync = nil
    }

    func isWatchlisted(_ item: MediaItem) -> Bool { watchlist.contains { $0.matches(item) } }
    func rating(for item: MediaItem) -> Int? { ratings.first { $0.matches(item) }?.rating }
    func progress(for item: MediaItem) -> Double? {
        guard let value = playback.first(where: { $0.matches(item) })?.progress,
              value.isFinite, value > 0, value < 100 else { return nil }
        return value
    }
    func isWatched(_ item: MediaItem) -> Bool {
        if item.type == .movie { return watchedMovies.contains { $0.matches(item) } }
        guard let season = item.seasonNumber, let episode = item.episodeNumber else { return false }
        return watchedShows.contains { entry in
            let matches = entry.show?.ids.matches(TraktIDs(imdb: item.imdbID, tmdb: item.tmdbID)) ?? false
            return matches && (entry.seasons?.contains { $0.number == season && $0.episodes.contains { $0.number == episode && ($0.plays ?? 1) > 0 } } ?? false)
        }
    }

    private func mutate(_ path: String, item: MediaItem, rating: Int? = nil) async throws {
        guard item.canSyncTrakt else { throw TraktError.missingMedia }
        do {
            let response: TraktSyncResult = try await client.request(path, method: "POST", body: item.traktSyncBody(rating: rating))
            if response.hasMissingItems { throw TraktError.missingMedia }
        } catch {
            report(error)
            throw error
        }
    }

    func setWatchlist(_ item: MediaItem, included: Bool) async throws {
        try await mutate("sync/watchlist" + (included ? "" : "/remove"), item: item)
        await refreshAfterMutation()
    }
    func setWatched(_ item: MediaItem, watched: Bool) async throws {
        // Avoid a second play from repeatedly pressing 'watched'.
        if watched && isWatched(item) { return }
        try await mutate("sync/history" + (watched ? "" : "/remove"), item: item)
        await refreshAfterMutation()
    }
    func setRating(_ item: MediaItem, rating: Int?) async throws {
        if let rating, !(1...10).contains(rating) { throw TraktError.invalidResponse }
        try await mutate("sync/ratings" + (rating == nil ? "/remove" : ""), item: item, rating: rating)
        await refreshAfterMutation()
    }
    func listItems(_ list: TraktList) async throws -> [TraktEntry] {
        try await client.allPages("users/me/lists/\(list.id)/items/movie,show,season,episode")
    }
    func add(_ item: MediaItem, to list: TraktList) async throws {
        try await mutate("users/me/lists/\(list.id)/items", item: item)
        await refreshAfterMutation()
    }
    func remove(_ entry: TraktEntry, from list: TraktList) async throws {
        guard let ids = entry.media?.ids else { throw TraktError.missingMedia }
        let data = try client.encoder.encode(ids)
        let object = try JSONSerialization.jsonObject(with: data)
        let plural = entry.kind == "movie" ? "movies" : entry.kind == "show" ? "shows" : entry.kind == "season" ? "seasons" : "episodes"
        let result: TraktSyncResult = try await client.request("users/me/lists/\(list.id)/items/remove", method: "POST", body: [plural: [["ids": object]]])
        if result.hasMissingItems { throw TraktError.missingMedia }
    }
    func createList(name: String) async throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let _: TraktList = try await client.request("users/me/lists", method: "POST", body: [
            "name": name, "privacy": "private", "allow_comments": false, "display_numbers": false
        ])
        await refreshAfterMutation()
    }
    func renameList(_ list: TraktList, name: String) async throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let _: TraktList = try await client.request("users/me/lists/\(list.id)", method: "PUT", body: ["name": name])
        await refreshAfterMutation()
    }
    func deleteList(_ list: TraktList) async throws {
        try await client.delete("users/me/lists/\(list.id)")
        await refreshAfterMutation()
    }
    func historyPage(_ page: Int) async throws -> [TraktEntry] {
        try await client.request("users/me/history?page=\(page)&limit=100")
    }

    /// Serialize start/pause/stop. Never replay a failed history mutation automatically:
    /// a timeout can mean the server already recorded it.
    func scrobble(_ action: String, item: MediaItem, progress: Double) {
        guard isConnected, scrobblingEnabled, item.canSyncTrakt, item.traktKind != "show",
              progress.isFinite else { return }
        if action != "start" && progress < 1 { return }
        let previous = scrobbleTail
        let snapshot = revision
        let boundedProgress = min(100, max(0, progress))
        scrobbleTail = Task { [weak self] in
            await previous?.value
            guard let self, !Task.isCancelled, self.revision == snapshot,
                  self.isConnected, self.scrobblingEnabled else { return }
            do {
                let _: TraktScrobbleResult = try await self.client.request("scrobble/\(action)", method: "POST", body: [
                    item.traktKind: item.traktObject(), "progress": boundedProgress
                ])
                if action == "stop" { await self.refreshAfterMutation() }
            } catch TraktError.http(409, _, _) {
                if action == "stop" { await self.refreshAfterMutation() }
            } catch is CancellationError { }
            catch {
                guard self.revision == snapshot else { return }
                self.isConnected = self.client.isAuthenticated
                if !self.isConnected { self.clearCachedData() }
                self.errorMessage = "Kijkvoortgang niet bevestigd door Trakt. \(error.localizedDescription)"
            }
        }
    }
}
