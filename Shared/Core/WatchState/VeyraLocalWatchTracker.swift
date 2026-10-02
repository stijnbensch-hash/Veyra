import Foundation
import Combine
import AetherEngine

/// Lokale, Trakt- en bron-onafhankelijke kijkvoortgang-tracker. Spiegelt de
/// structuur van `TraktPlaybackTracker`, maar schrijft naar
/// `VeyraWatchStateStore` in plaats van naar Trakt — werkt dus ook zonder
/// Trakt-account en voor bronnen zonder progress-sync (zie Regional
/// Releases-spec fase 7).
@MainActor
final class VeyraLocalWatchTracker {
    private let identity: VeyraWatchIdentity
    private weak var engine: AetherEngine?
    private var subscriptions: Set<AnyCancellable> = []
    private var hasPlayed = false
    private var finished = false
    private var lastProgress: Double = 0
    private var lastPersistAt: Date = .distantPast
    private let persistInterval: TimeInterval = 10

    /// Faalt stil wanneer het item geen `tmdbID` heeft -- lokale
    /// kijkstatus is alleen zinvol voor TMDB-gekoppelde content (net zoals
    /// `TraktStore.scrobble` al stil no-opt zonder Trakt-match).
    init?(item: MediaItem, engine: AetherEngine) {
        guard let tmdbID = item.tmdbID else { return nil }
        self.identity = VeyraWatchIdentity(
            tmdbID: tmdbID,
            season: item.seasonNumber,
            episode: item.episodeNumber
        )
        self.engine = engine
        engine.$state.sink { [weak self] state in self?.changed(state) }.store(in: &subscriptions)
        Timer.publish(every: 1, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in
                guard let self, let engine = self.engine else { return }
                self.sample()
                if engine.state == .playing { self.maybePersist() }
            }.store(in: &subscriptions)
    }

    private func sample() {
        guard let engine, let progress = TraktPlaybackTracker.progress(time: engine.currentTime, duration: engine.duration) else { return }
        lastProgress = progress
    }

    private func maybePersist(force: Bool = false) {
        let now = Date()
        guard force || now.timeIntervalSince(lastPersistAt) >= persistInterval else { return }
        lastPersistAt = now
        let identity = identity
        let progress = lastProgress
        Task { await VeyraWatchStateStore.shared.setProgress(identity, progress: progress, now: now) }
    }

    private func changed(_ state: PlaybackState) {
        guard !finished else { return }
        sample()
        switch state {
        case .playing:
            guard let engine, engine.duration.isFinite, engine.duration > 0 else { return }
            hasPlayed = true
            maybePersist()
        case .ended:
            guard hasPlayed else { return }
            lastProgress = 100
            finish(samplePosition: false)
        case .error:
            finish()
        case .paused, .idle, .loading, .seeking:
            break
        @unknown default: break
        }
    }

    func finish(samplePosition: Bool = true) {
        guard !finished else { return }
        if samplePosition { sample() }
        finished = true
        subscriptions.removeAll()
        guard hasPlayed else { return }
        maybePersist(force: true)
    }
}
