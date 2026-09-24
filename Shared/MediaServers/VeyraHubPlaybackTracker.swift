import Foundation
import Combine
import AetherEngine

/// Reports playback position to a VeyraHub server for the duration of one
/// playback session, so the same account can resume from any device (see
/// `PlayableSource.progressSync` / VeyraHub's `/api/v1/items/.../progress`
/// endpoints). Mirrors `TraktPlaybackTracker`'s shape (state-driven + a
/// periodic sample), but reports absolute seconds instead of a percentage
/// and talks to VeyraHub's native API instead of Trakt.
///
/// Every report is best-effort: a failed network call here must never
/// affect playback, so errors are only logged, never surfaced.
@MainActor
final class VeyraHubPlaybackTracker {
    private let sync: VeyraHubProgressSync
    private let client: VeyraHubNativeClient
    private weak var engine: AetherEngine?
    private var subscriptions: Set<AnyCancellable> = []
    private var finished = false
    private var hasPlayed = false
    private var lastReportedPosition: Double = -1

    /// Minimum time between position reports while playing. Position
    /// still updates every second locally (for an accurate value at
    /// pause/stop/finish); this only throttles the network calls.
    private static let reportInterval: TimeInterval = 15

    private var lastReportAt: Date = .distantPast

    init(
        sync: VeyraHubProgressSync,
        engine: AetherEngine,
        client: VeyraHubNativeClient? = nil
    ) {
        self.sync = sync
        self.engine = engine
        self.client = client ?? VeyraHubNativeClient(account: sync.account)

        Timer.publish(every: 1, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in self?.tick() }
            .store(in: &subscriptions)
    }

    private func tick() {
        guard !finished, let engine, engine.state == .playing else { return }
        hasPlayed = true

        guard
            engine.currentTime.isFinite, engine.currentTime >= 0,
            engine.duration.isFinite, engine.duration > 0
        else { return }

        guard Date().timeIntervalSince(lastReportAt) >= Self.reportInterval else { return }
        report(position: engine.currentTime, duration: engine.duration)
    }

    private func report(position: Double, duration: Double) {
        // Skip a report that wouldn't move the needle — playback paused
        // exactly on a previous report, or two ticks landing on the same
        // whole second.
        guard abs(position - lastReportedPosition) >= 1 else { return }

        lastReportedPosition = position
        lastReportAt = Date()

        let sync = self.sync
        let client = self.client
        Task {
            do {
                try await client.setProgress(
                    type: sync.mediaType,
                    id: sync.mediaID,
                    positionSeconds: position,
                    durationSeconds: duration
                )
            } catch {
                print("[VeyraHubPlaybackTracker] progress report mislukt: \(error.localizedDescription)")
            }
        }
    }

    /// Sends one final report and stops observing. Call when playback
    /// ends for any reason (finished, stopped, view dismissed, app
    /// backgrounded) — same lifecycle point `TraktPlaybackTracker.finish()`
    /// is called from.
    func finish() {
        guard !finished else { return }
        finished = true
        subscriptions.removeAll()

        guard
            hasPlayed, let engine,
            engine.currentTime.isFinite, engine.currentTime >= 0,
            engine.duration.isFinite, engine.duration > 0
        else { return }

        // Bypass the interval/delta throttle in report(): this is the
        // last chance to persist the real stop position.
        lastReportedPosition = -1
        lastReportAt = .distantPast
        report(position: engine.currentTime, duration: engine.duration)
    }
}
