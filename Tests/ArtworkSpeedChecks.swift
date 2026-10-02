import Foundation

// Service fixtures; the script compiles the actual Home model and TMDB adapter.
nonisolated enum GeneralSettingsDefaults {
    static let continueWatchingLimitKey = "fixture.artwork.limit"
}
@MainActor enum AppConfiguration {
    static let tmdbReadAccessToken: String? = "fixture-token"
    static let fanartAPIKey: String? = nil
}
nonisolated enum VeyraEndpoints {
    static let tmdb = "https://fixture.invalid"
    static let fanart = "https://fixture.invalid"
}
nonisolated struct TMDBLogo: Decodable {}
nonisolated struct MediaItem {
    enum Kind { case movie, series }
    let title: String
    let type: Kind
    let tmdbID: Int
}
actor ArtworkResolver {
    static let shared = ArtworkResolver()
    func clearLogoURL(for item: MediaItem) async -> URL? {
        do { try await Task.sleep(for: .milliseconds(800)) } catch { return nil }
        return URL(string: "https://fixture.invalid/logo.png")
    }
}
nonisolated struct TraktShowProgress {
    struct Episode { let season: Int?; let number: Int?; let title: String?; var firstAired: String? = nil }
    let completed: Int
    let aired: Int
    let nextEpisode: Episode?
    var lastWatchedAt: String? = nil
}
nonisolated struct FixtureShow {
    struct IDs { let trakt: Int?; let tmdb: Int? }
    let ids: IDs
    let title: String?
    let year: Int?
}
nonisolated struct FixtureUpNext {
    let show: FixtureShow
    let progress: TraktShowProgress
    var lastWatchedAt: String? = nil
}
nonisolated struct FixtureWatchEntry {
    let show: FixtureShow?
    var watchedAt: String? = nil
    var lastWatchedAt: String? = nil
}
@MainActor final class TraktStore {
    static let shared = TraktStore()
    var upNext: [FixtureUpNext] = []
    var watchedShows: [FixtureWatchEntry] = []
    var history: [FixtureWatchEntry] = []
}
nonisolated final class FixtureProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "fixture.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let data = Data(#"{"backdrops":[{"file_path":"/backdrop.jpg","iso_639_1":null,"vote_average":9}],"logos":[]}"#.utf8)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
actor Probe {
    var firstUpdate: ContinuousClock.Instant?
    var active = 0
    var maximum = 0
    var total = 0
    func recordUpdate() { firstUpdate = ContinuousClock().now }
    func started() { active += 1; total += 1; maximum = max(maximum, active) }
    func finished() { active -= 1 }
}
nonisolated struct Source: TraktHomeProviding {
    let items: [ContinueItem]
    var probe: Probe? = nil
    func continueWatching(limit: Int) async throws -> [ContinueItem] {
        await probe?.started()
        return Array(items.prefix(limit))
    }
    func upcoming(days: Int) async throws -> [UpcomingItem] { [] }
    func removePlayback(id: Int) async throws {}
}
nonisolated struct ArtworkSource: ArtworkProviding {
    let probe: Probe
    func artwork(for kind: MediaKind, tmdbID: Int) async -> Artwork? { nil }
    func artwork(for kind: MediaKind, tmdbID: Int,
                 onUpdate: @escaping @Sendable (Artwork) async -> Void) async -> Artwork? {
        await probe.started()
        let art = Artwork(backdrop: URL(string: "https://fixture.invalid/\(tmdbID).jpg"), logo: nil)
        await onUpdate(art)
        try? await Task.sleep(for: .milliseconds(300))
        await probe.finished()
        return Task.isCancelled ? nil : art
    }
}
nonisolated struct CachedHome: Codable { let continueItems: [ContinueItem]; let upcoming: [UpcomingItem] }

@main struct ArtworkSpeedChecks {
    @MainActor static func main() async throws {
        precondition(VeyraHomeFormat.traktDate("2026-10-02") == VeyraHomeFormat.traktDate("2026-10-02T00:00:00Z"))
        precondition(VeyraHomeFormat.traktDate("invalid") == nil)
        URLProtocol.registerClass(FixtureProtocol.self)
        let probe = Probe()
        let start = ContinuousClock().now
        let art = await VeyraTMDBArtwork().artwork(for: .movie, tmdbID: 1) { partial in
            precondition(partial.backdrop != nil && partial.logo == nil)
            await probe.recordUpdate()
        }
        let end = ContinuousClock().now
        let first = await probe.firstUpdate!
        precondition(art?.logo != nil)
        precondition(first.duration(to: end) > .milliseconds(650), "backdrop must arrive before the slow optional logo")
        print("PASS backdrop delivered at \(start.duration(to: first)); full artwork at \(start.duration(to: end)) (mock 800ms logo)")

        let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("veyra-home-cache.json")
        let previous = try? Data(contentsOf: cacheURL)
        defer {
            if let previous { try? previous.write(to: cacheURL, options: .atomic) }
            else { try? FileManager.default.removeItem(at: cacheURL) }
            UserDefaults.standard.removeObject(forKey: GeneralSettingsDefaults.continueWatchingLimitKey)
        }
        func item(_ id: Int) -> ContinueItem {
            ContinueItem(id: "fixture-\(id)", playbackID: id, kind: .movie, title: "Fixture",
                year: nil, episodeCode: nil, episodeTitle: nil, progress: 0.5, remainingMinutes: 30,
                tmdbID: id, showTraktID: nil, lastWatched: Date(), isUpNext: false)
        }
        var cached = item(1)
        cached.backdropURL = URL(string: "https://fixture.invalid/cached.jpg")
        cached.logoURL = URL(string: "https://fixture.invalid/cached-logo.png")
        try JSONEncoder().encode(CachedHome(continueItems: [cached], upcoming: [])).write(to: cacheURL, options: .atomic)
        let cachedProbe = Probe()
        let restored = VeyraHomeViewModel(provider: Source(items: [item(1)]), artwork: ArtworkSource(probe: cachedProbe))
        await restored.load()
        precondition(restored.continueItems[0].backdropURL == cached.backdropURL)
        precondition(restored.continueItems[0].logoURL == cached.logoURL)
        let restoredRequests = await cachedProbe.total
        precondition(restoredRequests == 0, "known artwork must survive fresh Trakt data without new requests")
        print("PASS restored URLs survive refresh; zero repeated metadata requests")

        try FileManager.default.removeItem(at: cacheURL)
        UserDefaults.standard.set(50, forKey: GeneralSettingsDefaults.continueWatchingLimitKey)
        let groupProbe = Probe()
        let model = VeyraHomeViewModel(provider: Source(items: (1...25).map(item)), artwork: ArtworkSource(probe: groupProbe))
        let load = Task { await model.load() }
        for _ in 0..<100 {
            if await groupProbe.total >= 6 { break }
            try await Task.sleep(for: .milliseconds(5))
        }
        precondition(model.continueItems.filter { $0.backdropURL != nil }.count >= 6)
        await load.value
        let maximum = await groupProbe.maximum
        let total = await groupProbe.total
        precondition(maximum == 6 && total == 25)
        precondition(model.continueItems.allSatisfy { $0.backdropURL != nil })
        print("PASS progressive Home updates and bounded metadata concurrency: peak=\(maximum), items=\(total)")

        // A full checkpoint list must not crowd out a newly aired or recently
        // watched series. Missing dates must not be replaced with refresh time.
        UserDefaults.standard.set(2, forKey: GeneralSettingsDefaults.continueWatchingLimitKey)
        let now = Date()
        func timestamp(_ age: TimeInterval) -> String { now.addingTimeInterval(-age).ISO8601Format() }
        func next(_ id: Int, watchedAge: TimeInterval?, releaseAge: TimeInterval?, completed: Int = 1) -> FixtureUpNext {
            FixtureUpNext(show: FixtureShow(ids: .init(trakt: id, tmdb: id), title: "Fixture", year: nil),
                progress: TraktShowProgress(completed: completed, aired: 2,
                    nextEpisode: .init(season: 2, number: 1, title: "Fixture", firstAired: releaseAge.map(timestamp)),
                    lastWatchedAt: watchedAge.map(timestamp)))
        }
        var oldPause = item(100)
        // Source items are immutable dates, so construct an old real checkpoint.
        oldPause = ContinueItem(id: "pb-old", playbackID: 100, kind: .movie, title: "Old pause",
            year: nil, episodeCode: nil, episodeTitle: nil, progress: 0.9, remainingMinutes: 3,
            tmdbID: 100, showTraktID: nil, lastWatched: now.addingTimeInterval(-86400), isUpNext: false)
        let olderPause = ContinueItem(id: "pb-older", playbackID: 101, kind: .movie, title: "Older pause",
            year: nil, episodeCode: nil, episodeTitle: nil, progress: 0.5, remainingMinutes: 30,
            tmdbID: 101, showTraktID: nil, lastWatched: now.addingTimeInterval(-172800), isUpNext: false)
        TraktStore.shared.upNext = [next(1, watchedAge: 604800, releaseAge: 60),
            next(2, watchedAge: 300, releaseAge: 604800), next(3, watchedAge: nil, releaseAge: nil),
            next(4, watchedAge: 10, releaseAge: -86400), next(5, watchedAge: 10, releaseAge: 10, completed: 2)]
        let ordered = VeyraHomeViewModel(provider: Source(items: [oldPause, olderPause]))
        await ordered.load()
        precondition(ordered.continueItems.map(\.tmdbID) == [1, 2], "released/recently watched shows must rank ahead of old progress, before limit")
        let firstDates = ordered.continueItems.map(\.lastWatched)
        await ordered.load()
        precondition(ordered.continueItems.map(\.lastWatched) == firstDates, "refresh must not fabricate new activity dates")
        print("PASS new releases and recent watch activity outrank a full checkpoint list; no fabricated dates")

        UserDefaults.standard.set(50, forKey: GeneralSettingsDefaults.continueWatchingLimitKey)
        let unbounded = VeyraHomeViewModel(provider: Source(items: [oldPause, olderPause]))
        await unbounded.load()
        precondition(unbounded.continueItems.map(\.tmdbID) == [1, 2, 100, 101, 3])
        // Watch-history fallback, missing dates, equal-date determinism, and one
        // resume card per show remain usable without extra network requests.
        TraktStore.shared.history = [.init(show: .init(ids: .init(trakt: 3, tmdb: 3), title: "Fixture", year: nil), watchedAt: timestamp(30))]
        await unbounded.load()
        precondition(unbounded.continueItems.first?.tmdbID == 3)
        TraktStore.shared.upNext = [next(1, watchedAge: 60, releaseAge: 120), next(1, watchedAge: 60, releaseAge: 120)]
        let checkpoint = ContinueItem(id: "pb-show", playbackID: 200, kind: .episode, title: "Show checkpoint",
            year: nil, episodeCode: "S02E01", episodeTitle: nil, progress: 0.2, remainingMinutes: 20,
            tmdbID: 1, showTraktID: 1, lastWatched: now.addingTimeInterval(-20), isUpNext: false)
        let deduplicated = VeyraHomeViewModel(provider: Source(items: [checkpoint, oldPause]))
        await deduplicated.load()
        precondition(deduplicated.continueItems.count == 2 && deduplicated.continueItems.first?.playbackID == 200)
        TraktStore.shared.upNext = []
        TraktStore.shared.history = []
        print("PASS future/finished exclusions, watch-history fallback, missing-date fallback and checkpoint deduplication")
        let fetchProbe = Probe()
        let lateSnapshot = VeyraHomeViewModel(provider: Source(items: [oldPause], probe: fetchProbe))
        await lateSnapshot.load()
        TraktStore.shared.upNext = [next(6, watchedAge: 30, releaseAge: 120)]
        await lateSnapshot.refreshContinueOrder()
        precondition(lateSnapshot.continueItems.first?.tmdbID == 6)
        let fetches = await fetchProbe.total
        precondition(fetches == 1, "late snapshots must re-rank without a second playback request")
        TraktStore.shared.upNext = []
        print("PASS late Trakt snapshot re-ranks locally without additional playback requests")
    }
}
