import Foundation

/// Reconcileert `VeyraWatchStateStore`-items (lokale/VeyraHub kijkstatus
/// voor regionale releases die Trakt nog niet kent) zodra een betrouwbare
/// Trakt-identiteit beschikbaar wordt -- Regional Releases spec fase 9.
///
/// Draait periodiek op een rustig interval, nooit per card of per focus
/// (spec §47), en is uitsluitend additief: ontbrekende "bekeken"-historie
/// wordt naar Trakt geüpload, Trakt-historie die lokaal nog ontbrak wordt
/// overgenomen, maar niets wordt ooit verwijderd (spec §50/§83). Een
/// mislukte of onbetrouwbare match laat een item gewoon `pendingTraktMatch`
/// (traktID == nil) -- de volgende cyclus probeert het opnieuw.
@MainActor
final class VeyraTraktWatchStateReconciler {
    static let shared = VeyraTraktWatchStateReconciler()

    private static let interval: TimeInterval = 10 * 60

    private var started = false
    private var running = false
    private var scheduled: Task<Void, Never>?

    private init() {}

    func start() {
        guard !started else { return }
        started = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(traktStateChanged),
            name: .veyraTraktHistoryDidChange, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(traktStateChanged),
            name: .veyraWatchStateDidChange, object: nil)
        schedule(after: 10)
    }

    @objc private func traktStateChanged() { schedule(after: 5) }

    private func schedule(after seconds: TimeInterval) {
        guard !running else { return }
        scheduled?.cancel()
        scheduled = Task { [weak self] in
            if seconds > 0 { try? await Task.sleep(for: .seconds(seconds)) }
            guard !Task.isCancelled else { return }
            await self?.reconcile()
        }
    }

    private func reconcile() async {
        guard !running else { return }
        running = true
        defer {
            running = false
            schedule(after: Self.interval)
        }

        // Trakt-storing mag Home/playback/VeyraHub nooit blokkeren (spec §63)
        // -- simpelweg niets doen en volgende cyclus opnieuw proberen.
        guard TraktStore.shared.isConnected else { return }

        let pending = await VeyraWatchStateStore.shared.allStates().filter { $0.traktID == nil }
        guard !pending.isEmpty else { return }

        for entry in pending {
            await reconcile(entry)
        }
    }

    private func reconcile(_ entry: VeyraWatchState) async {
        guard let season = entry.identity.season, let episode = entry.identity.episode else { return }

        // Stap 1: betrouwbare episode-identiteit vinden (TMDB episode-ID) --
        // nooit alleen op titel matchen (spec §29).
        guard let service = SeriesService(),
              let seasonDetails = try? await service.season(seriesID: entry.identity.tmdbID, seasonNumber: season),
              let episodeTMDBID = seasonDetails.episodes.first(where: { $0.episodeNumber == episode })?.id
        else { return }

        let item = MediaItem(
            title: seasonDetails.name,
            type: .series,
            tmdbID: entry.identity.tmdbID,
            episodeTMDBID: episodeTMDBID,
            seasonNumber: season,
            episodeNumber: episode
        )
        guard item.canSyncTrakt else { return }

        // Stap 2 + 3: vergelijken/mergen, nooit destructief (spec §48-50).
        if TraktStore.shared.isWatched(item) {
            // Trakt kent 'm al -- lokale/VeyraHub-status mag nooit terug, dus
            // enkel aanvullen als lokaal nog niet "bekeken" stond.
            if !entry.watched {
                await VeyraWatchStateStore.shared.setWatched(entry.identity, watched: true)
            }
        } else if entry.watched {
            // Ontbrekende watched-historie uploaden (spec §48). Mislukt dit
            // (netwerk/Trakt-fout), dan blijft het item gewoon pending --
            // geen dataverlies, niets wordt elders weggehaald (spec §83).
            try? await TraktStore.shared.setWatched(item, watched: true)
            guard TraktStore.shared.isWatched(item) else { return }
        }
        // Partial progress (watched == false) wordt hier bewust NIET naar
        // Trakt gescrobbeld -- dat loopt al via de normale afspeel-flow
        // (`TraktPlaybackTracker`). Deze reconciliatie raakt partial
        // progress niet aan, dus gaat er niets van verloren (spec §50).

        // Stap 4: reconciliatie bevestigen. `traktID` bewaart hier het TMDB
        // episode-ID waarmee de koppeling betrouwbaar is vastgesteld --
        // Trakt's eigen sync-API identificeert een episode al via exact dit
        // ID (zie `MediaItem.traktIDs`/`traktObject()`), dus is geen aparte
        // opvraag van Trakt's eigen interne episode-ID nodig.
        await VeyraWatchStateStore.shared.setTraktID(entry.identity, traktID: episodeTMDBID)
    }
}
