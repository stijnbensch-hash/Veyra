import Foundation

// De Trakt-store deelt deze notificatie en cache-invalidator met Bento Home.
// Deze gerichte controles bouwen de volledige Home-weergave niet mee.
extension Notification.Name {
    static let veyraTraktHistoryDidChange = Notification.Name("veyra.trakt.historyDidChange")
    static let veyraTraktSnapshotDidChange = Notification.Name("veyra.trakt.snapshotDidChange")
}

final class TraktHomeThrottle {
    static let shared = TraktHomeThrottle()
    func invalidate() { }
}

final class MemoryTokens: TraktTokenStorage {
    var data: Data?
    var writes = 0
    var failWrites = false
    func read() throws -> Data? { data }
    func save(_ data: Data) throws {
        if failWrites { throw TraktError.storage }
        self.data = data; writes += 1
    }
    func delete() throws { data = nil }
}

final class MockTraktProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (Int, [String: String], Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, headers, data) = try Self.handler!(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() { }
}

@main
struct TraktIntegrationChecks {
    @MainActor static func main() async throws {
        let activityDecoder = JSONDecoder()
        activityDecoder.keyDecodingStrategy = .convertFromSnakeCase
        let upNextJSON = Data(#"{"show":{"ids":{"trakt":10}},"last_watched_at":"2026-10-02T20:00:00.000Z","progress":{"aired":2,"completed":1,"last_watched_at":"2026-10-02T19:00:00Z","next_episode":{"ids":{"trakt":20},"season":1,"number":2,"first_aired":"2026-10-02T21:00:00.000Z"}}}"#.utf8)
        let dated = try activityDecoder.decode(TraktUpNext.self, from: upNextJSON)
        precondition(dated.lastWatchedAt == "2026-10-02T20:00:00.000Z")
        precondition(dated.progress.lastWatchedAt == "2026-10-02T19:00:00Z")
        precondition(dated.progress.nextEpisode?.firstAired == "2026-10-02T21:00:00.000Z")
        let oldCacheJSON = Data(#"{"show":{"ids":{"trakt":10}},"progress":{"aired":2,"completed":1}}"#.utf8)
        let undated = try activityDecoder.decode(TraktUpNext.self, from: oldCacheJSON)
        precondition(undated.lastWatchedAt == nil && undated.progress.lastWatchedAt == nil)
        let watchedJSON = Data(#"{"show":{"ids":{"trakt":10}},"last_watched_at":"2026-10-02T20:00:00Z"}"#.utf8)
        let watchedDateEntry = try activityDecoder.decode(TraktEntry.self, from: watchedJSON)
        precondition(watchedDateEntry.lastWatchedAt == "2026-10-02T20:00:00Z")
        print("PASS Trakt watch/release dates decode from API fields and old caches remain readable")
        let watchedIDs = TraktIDs(tmdb: 777)
        let watchedShow = TraktMedia(title: "Test", ids: watchedIDs)
        let watchedEntry = TraktEntry(show: watchedShow, seasons: [
            TraktWatchedSeason(number: 1, episodes: [TraktWatchedEpisode(number: 1, plays: 2), TraktWatchedEpisode(number: 1, plays: 1), TraktWatchedEpisode(number: 2, plays: 0)])
        ])
        func watchedStatus(_ target: TraktWatchedTarget, progress: [TraktUpNext] = []) -> TraktWatchedStatus {
            .resolve(target, movies: [TraktEntry(movie: watchedShow, plays: 1)], shows: [watchedEntry], progress: progress)
        }
        precondition(watchedStatus(.movie(watchedIDs)) == .watched)
        precondition(watchedStatus(.movie(TraktIDs(tmdb: 888))) == .none)
        precondition(watchedStatus(.episode(show: watchedIDs, season: 1, number: 1)) == .watched)
        precondition(watchedStatus(.episode(show: watchedIDs, season: 1, number: 2)) == .none)
        precondition(watchedStatus(.season(show: watchedIDs, number: 1, episodeCount: 2)) == .partial(count: 1, total: 2))
        precondition(watchedStatus(.season(show: watchedIDs, number: 1, episodeCount: 1)) == .watched)
        precondition(watchedStatus(.season(show: watchedIDs, number: 1, episodeCount: 0)) == .partial(count: 1, total: nil))
        precondition(watchedStatus(.show(watchedIDs)) == .watched)
        precondition(watchedStatus(.show(watchedIDs), progress: [TraktUpNext(show: watchedShow, progress: TraktShowProgress(aired: 4, completed: 4))]) == .watched)
        precondition(watchedStatus(.show(watchedIDs), progress: [TraktUpNext(show: watchedShow, progress: TraktShowProgress(aired: 4, completed: 2))]) == .partial(count: 2, total: 4))
        print("PASS watched badges: identity, episode plays, duplicate watches, partial seasons, unknown totals and series completion")
        let credentials = TraktCredentials(clientID: "test-client", clientSecret: "test-secret", redirectURI: "urn:ietf:wg:oauth:2.0:oob")
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockTraktProtocol.self]
        let session = URLSession(configuration: config)
        let storage = MemoryTokens()
        let encoder = JSONEncoder(); encoder.keyEncodingStrategy = .convertToSnakeCase
        let oldToken = TraktToken(accessToken: "old", refreshToken: "single-use", expiresIn: 0, createdAt: 0)
        storage.data = try encoder.encode(oldToken)
        let client = TraktClient(credentials: credentials, session: session, tokenStorage: storage)
        nonisolated(unsafe) var refreshes = 0
        MockTraktProtocol.handler = { request in
            precondition(request.value(forHTTPHeaderField: "trakt-api-key") == "test-client")
            precondition(request.value(forHTTPHeaderField: "trakt-api-version") == "2")
            if request.url!.path == "/oauth/token" {
                refreshes += 1
                precondition(request.url!.host == "auth.trakt.tv")
                return (200, [:], Data("{\"access_token\":\"new\",\"refresh_token\":\"rotated\",\"expires_in\":604800,\"created_at\":\(Date().timeIntervalSince1970)}".utf8))
            }
            precondition(request.value(forHTTPHeaderField: "Authorization") == "Bearer new")
            return (200, [:], Data("[]".utf8))
        }
        async let first: [TraktEntry] = client.request("sync/playback/movies")
        async let second: [TraktEntry] = client.request("sync/playback/episodes")
        _ = try await (first, second)
        precondition(refreshes == 1 && storage.writes == 1, "Single-use refresh must be serialized and saved exactly once")
        print("PASS concurrent token refresh and rotated token persistence")

        nonisolated(unsafe) var pages: [String] = []
        MockTraktProtocol.handler = { request in
            let page = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!.first { $0.name == "page" }!.value!
            pages.append(page)
            return (200, ["X-Pagination-Page-Count": "2"], Data("[{\"id\":\(page),\"movie\":{\"title\":\"Movie\",\"ids\":{\"tmdb\":\(page)}}}]".utf8))
        }
        let entries: [TraktEntry] = try await client.allPages("sync/watchlist/movies/added/desc")
        precondition(entries.count == 2 && pages == ["1", "2"])
        print("PASS complete pagination")

        MockTraktProtocol.handler = { _ in (429, ["Retry-After": "0.01"], Data("{}".utf8)) }
        do {
            let _: [TraktEntry] = try await client.request("sync/playback/movies")
            fatalError("Expected rate limit")
        } catch TraktError.http(let status, let retry, _) { precondition(status == 429 && retry == 0.01) }
        print("PASS explicit rate-limit handling")
        try await Task.sleep(for: .milliseconds(20))

        let episode = MediaItem(title: "Episode", type: .series, imdbID: "tt-show", tmdbID: 123,
                                episodeTMDBID: 456, seasonNumber: 1, episodeNumber: 2)
        let object = episode.traktObject()["ids"] as! [String: Any]
        precondition(object["tmdb"] as? Int == 456 && object["imdb"] == nil)
        let unidentified = MediaItem(title: "Episode", type: .series, imdbID: "tt-show", seasonNumber: 1, episodeNumber: 2)
        precondition(!unidentified.canSyncTrakt)
        let watched: TraktEntry = try client.decoder.decode(TraktEntry.self, from: Data("{\"plays\":1,\"show\":{\"title\":\"Show\",\"ids\":{\"tmdb\":123}},\"seasons\":[{\"number\":1,\"episodes\":[{\"number\":2,\"plays\":1}]}]}".utf8))
        precondition(watched.seasons?.first?.episodes.first?.number == 2)
        let missing = try client.decoder.decode(TraktSyncResult.self, from: Data("{\"not_found\":{\"episodes\":[{\"ids\":{\"tmdb\":456}}]}}".utf8))
        precondition(missing.hasMissingItems)
        print("PASS episode versus show identity, watched decoding, missing item detection")

        let pollStorage = MemoryTokens()
        let polling = TraktClient(credentials: credentials, session: session, tokenStorage: pollStorage)
        nonisolated(unsafe) var polls = 0
        MockTraktProtocol.handler = { request in
            precondition(request.url!.path == "/oauth/device/token")
            precondition(request.value(forHTTPHeaderField: "Authorization") == nil)
            polls += 1
            if polls == 1 { return (400, [:], Data("{\"error\":\"authorization_pending\"}".utf8)) }
            return (200, [:], Data("{\"access_token\":\"linked\",\"refresh_token\":\"refresh\",\"expires_in\":604800,\"created_at\":\(Date().timeIntervalSince1970)}".utf8))
        }
        let code = TraktDeviceCode(deviceCode: "device", userCode: "ABCD1234", verificationUrl: "https://auth.trakt.tv/activate", expiresIn: 10, interval: 1)
        try await polling.authorize(code, receivedAt: Date())
        precondition(polls == 2 && polling.isAuthenticated && pollStorage.writes == 1)
        print("PASS device authorization pending then success")

        let canceledStorage = MemoryTokens()
        let canceled = TraktClient(credentials: credentials, session: session, tokenStorage: canceledStorage)
        let task = Task { try await canceled.authorize(code, receivedAt: Date()) }
        task.cancel()
        do { try await task.value; fatalError("Expected cancellation") } catch is CancellationError { }
        precondition(!canceled.isAuthenticated && canceledStorage.writes == 0)
        do { try await canceled.authorize(code, receivedAt: Date().addingTimeInterval(-20)); fatalError("Expected expired code") }
        catch TraktError.expiredCode { }
        print("PASS cancellation and code expiry never store a token")

        let expiredStorage = MemoryTokens(); expiredStorage.data = try encoder.encode(oldToken)
        let expired = TraktClient(credentials: credentials, session: session, tokenStorage: expiredStorage)
        MockTraktProtocol.handler = { _ in (400, [:], Data("{\"error\":\"invalid_grant\",\"error_description\":\"session not found\"}".utf8)) }
        do { let _: [TraktEntry] = try await expired.request("sync/playback/movies"); fatalError("Expected invalid_grant") }
        catch TraktError.http(400, _, let reason) { precondition(reason == "invalid_grant") }
        precondition(!expired.isAuthenticated && expiredStorage.data == nil)
        print("PASS revoked refresh token clears local authentication")

        MockTraktProtocol.handler = { _ in (503, [:], Data("{}".utf8)) }
        do { try await polling.disconnect(); fatalError("Expected failed remote revocation") }
        catch TraktError.http(503, _, _) { }
        precondition(!polling.isAuthenticated && pollStorage.data == nil)
        print("PASS offline disconnect removes local tokens")

        let failedStorage = MemoryTokens(); failedStorage.failWrites = true
        let failed = TraktClient(credentials: credentials, session: session, tokenStorage: failedStorage)
        MockTraktProtocol.handler = { _ in
            (200, [:], Data("{\"access_token\":\"linked\",\"refresh_token\":\"refresh\",\"expires_in\":604800,\"created_at\":\(Date().timeIntervalSince1970)}".utf8))
        }
        do { try await failed.authorize(code, receivedAt: Date()); fatalError("Expected storage failure") }
        catch TraktError.storage { }
        precondition(!failed.isAuthenticated)
        print("PASS secure storage failure cannot report a successful link")
        let storeStorage = MemoryTokens()
        storeStorage.data = try encoder.encode(TraktToken(accessToken: "store", refreshToken: "refresh", expiresIn: 604800, createdAt: Date().timeIntervalSince1970))
        let storeClient = TraktClient(credentials: credentials, session: session, tokenStorage: storeStorage)
        let testPreferences = UserDefaults(suiteName: "veyra.trakt.checks.\(UUID().uuidString)")!
        let store = TraktStore(client: storeClient, preferences: testPreferences)
        nonisolated(unsafe) var events: [String] = []
        nonisolated(unsafe) var writes: [String] = []
        nonisolated(unsafe) var missingTitle = false
        nonisolated(unsafe) var failLibrary = true
        nonisolated(unsafe) var failWatched = false
        nonisolated(unsafe) var moviePlaybackAvailable = false
        nonisolated(unsafe) var episodePlaybackAvailable = false
        nonisolated(unsafe) var failPlaybackDelete = false
        nonisolated(unsafe) var deletedPlayback: [String] = []
        MockTraktProtocol.handler = { request in
            let path = request.url!.path
            if path.hasPrefix("/scrobble/") {
                events.append(path)
                return (201, [:], Data("{\"action\":\"pause\"}".utf8))
            }
            if request.httpMethod == "POST" {
                writes.append(path)
                if missingTitle { return (200, [:], Data("{\"not_found\":{\"episodes\":[{\"ids\":{\"tmdb\":456}}]}}".utf8)) }
                return (200, [:], Data("{\"not_found\":{}}".utf8))
            }
            if request.httpMethod == "DELETE", path.hasPrefix("/sync/playback/") {
                deletedPlayback.append(path)
                if failPlaybackDelete { return (503, [:], Data("{}".utf8)) }
                if path == "/sync/playback/51" { moviePlaybackAvailable = false }
                if path == "/sync/playback/52" { episodePlaybackAvailable = false }
                return (204, [:], Data())
            }
            if path == "/users/settings" {
                return (200, [:], Data("{\"user\":{\"username\":\"test\",\"ids\":{\"slug\":\"test\"}}}".utf8))
            }
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems ?? []
            if path == "/sync/playback/movies" {
                let json = moviePlaybackAvailable
                    ? "[{\"id\":51,\"progress\":42,\"movie\":{\"title\":\"Film\",\"ids\":{\"tmdb\":777}}}]"
                    : "[]"
                return (200, [:], Data(json.utf8))
            }
            if path == "/sync/playback/episodes" {
                let json = episodePlaybackAvailable
                    ? "[{\"id\":52,\"progress\":36,\"show\":{\"title\":\"Show\",\"ids\":{\"tmdb\":123}},\"episode\":{\"season\":1,\"number\":2,\"ids\":{}}}]"
                    : "[]"
                return (200, [:], Data(json.utf8))
            }
            if path == "/users/me/ratings/movies", failLibrary { return (503, [:], Data()) }
            if path == "/sync/watched/movies" {
                if failWatched { return (503, [:], Data()) }
                let page = query.first(where: { $0.name == "page" })?.value ?? "missing"
                precondition(page == "1" || page == "2")
                let id = page == "1" ? 777 : 888
                return (200, ["X-Pagination-Page-Count": "2", "X-Pagination-Limit": "1"], Data("[{\"movie\":{\"ids\":{\"tmdb\":\(id)}},\"plays\":1}]".utf8))
            }
            if path == "/sync/watched/shows" {
                precondition(query.first(where: { $0.name == "extended" })?.value == "progress", "Episode watched-state requires extended=progress")
                if failWatched { return (503, [:], Data()) }
                return (200, [:], Data("[{\"show\":{\"ids\":{\"tmdb\":123}},\"seasons\":[{\"number\":1,\"episodes\":[{\"number\":2,\"plays\":1}]}]}]".utf8))
            }
            return (200, [:], Data("[]".utf8))
        }
        await store.refresh()
        precondition(store.lastSync != nil && store.lastWatchedSync != nil && store.isWatched(episode), "A failed ratings request must not discard successful snapshot groups")
        precondition(store.watchedMovies.count == 2 && store.watchedMovies.last?.movie?.ids.tmdb == 888)
        precondition(store.ratings.isEmpty, "Failed ratings preserve the previous group")
        print("PASS watched data loads across pages and remains visible when another Trakt endpoint fails")
        failLibrary = false
        await store.refresh()
        precondition(store.lastSync != nil && store.user?.username == "test" && store.isWatched(episode))
        try await store.setWatched(episode, watched: true)
        precondition(writes.isEmpty, "Already watched must not create an extra play")
        store.scrobble("start", item: episode, progress: 10)
        try await Task.sleep(for: .milliseconds(50))
        precondition(events.isEmpty, "Automatic sharing requires explicit consent")
        store.scrobblingEnabled = true
        store.scrobble("start", item: episode, progress: 10)
        store.scrobble("pause", item: episode, progress: 20)
        store.scrobble("stop", item: episode, progress: 25)
        for _ in 0..<100 {
            if events.count == 3 && !store.isSyncing { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        precondition(events == ["/scrobble/start", "/scrobble/pause", "/scrobble/stop"])
        print("PASS store sync, duplicate history guard, sharing opt-in and ordered playback events")
        let movie = MediaItem(title: "Film", type: .movie, tmdbID: 777)
        let nextEpisode = MediaItem(title: "Episode", type: .series, tmdbID: 123,
                                    seasonNumber: 1, episodeNumber: 3)
        moviePlaybackAvailable = true
        episodePlaybackAvailable = true
        await store.refresh()
        precondition(store.progress(for: movie) == 42 && store.progress(for: episode) == 36)
        precondition(store.progress(for: nextEpisode) == nil, "Afleveringsreset mag geen ander hervatpunt raken")
        precondition(store.isWatched(movie) && store.isWatched(episode))
        try await store.resetProgress(for: episode)
        try await store.resetProgress(for: movie)
        precondition(deletedPlayback == ["/sync/playback/52", "/sync/playback/51"])
        precondition(store.progress(for: movie) == nil && store.progress(for: episode) == nil)
        precondition(store.isWatched(movie) && store.isWatched(episode), "Reset mag bekeken-status niet wijzigen")
        precondition(store.wasProgressReset(for: movie) && store.wasProgressReset(for: episode))
        episodePlaybackAvailable = true
        await store.refresh()
        failPlaybackDelete = true
        do { try await store.resetProgress(for: episode); fatalError("Expected playback deletion failure") }
        catch TraktError.http(503, _, _) { }
        precondition(store.progress(for: episode) == 36 && store.isWatched(episode), "Mislukte reset bewaart lokale voortgang")
        failPlaybackDelete = false
        print("PASS playback reset deletes Trakt checkpoint, preserves watched status and keeps progress on failure")
        missingTitle = true
        do { try await store.setRating(episode, rating: 7); fatalError("Expected missing title") }
        catch TraktError.missingMedia { }
        precondition(store.rating(for: episode) == nil)
        print("PASS HTTP success with not_found cannot report a saved rating")
        failWatched = true
        await store.refresh()
        precondition(store.watchedMovies.count == 2 && store.isWatched(episode), "Failed watched refresh preserves last successful data")
        print("PASS failed watched refresh preserves existing badges")
        await store.disconnect()
        precondition(store.lastWatchedSync == nil)
        precondition(!store.isConnected && store.user == nil && store.watchedShows.isEmpty && !store.scrobblingEnabled)
        print("PASS disconnect clears account data and sharing consent")
        print("All Trakt integration checks passed; no live account or network was used.")
    }
}
