import Foundation
import Combine
import AetherEngine

/// Deletes a VeyraHub Recorder recording once it has been watched to (close
/// to) the end, when "Verwijder automatisch na kijken" is on. Mirrors
/// `VeyraHubPlaybackTracker`'s shape (ticks while playing, a `finish()`
/// called at every point playback stops), but instead of periodically
/// reporting position it only acts once, at `finish()`, using the last
/// known position/duration.
///
/// Every deletion is best-effort: a failed network call here must never
/// affect playback, and never surfaces an error to the person watching —
/// this is on cleanup, they're already done watching.
@MainActor
final class VeyraHubRecorderCleanupTracker {
    private let cleanup: VeyraHubRecorderCleanup
    private let client: VeyraHubRecorderClient
    private weak var engine: AetherEngine?
    private var finished = false
    private var hasPlayed = false
    private var lastKnownPosition: Double = 0
    private var lastKnownDuration: Double = 0
    private var subscriptions: Set<AnyCancellable> = []

    /// A recording counts as "watched" once playback reached this fraction
    /// of its duration — matches the common DVR convention of treating the
    /// last few percent (credits, black frames) as "finished" rather than
    /// requiring the exact final second.
    private static let watchedThreshold: Double = 0.92

    init(
        cleanup: VeyraHubRecorderCleanup,
        engine: AetherEngine,
        client: VeyraHubRecorderClient? = nil
    ) {
        self.cleanup = cleanup
        self.engine = engine
        self.client = client ?? VeyraHubRecorderClient(account: cleanup.account)

        Timer.publish(every: 1, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in self?.tick() }
            .store(in: &subscriptions)
    }

    private func tick() {
        guard !finished, let engine, engine.state == .playing else { return }
        hasPlayed = true
        guard engine.currentTime.isFinite, engine.currentTime >= 0 else { return }
        lastKnownPosition = engine.currentTime
        if engine.duration.isFinite, engine.duration > 0 {
            lastKnownDuration = engine.duration
        }
    }

    /// Call when playback ends for any reason — same lifecycle point
    /// `VeyraHubPlaybackTracker.finish()` is called from.
    func finish() {
        guard !finished else { return }
        finished = true
        subscriptions.removeAll()

        guard
            RecorderSettingsDefaults.autoDeleteAfterWatched(),
            hasPlayed, lastKnownDuration > 0,
            lastKnownPosition / lastKnownDuration >= Self.watchedThreshold
        else { return }

        let cleanup = self.cleanup
        let client = self.client
        Task {
            do {
                try await client.deleteRecording(id: cleanup.recordingID)
            } catch {
                print("[VeyraHubRecorderCleanupTracker] automatisch verwijderen mislukt: \(error.localizedDescription)")
            }
        }
    }
}
