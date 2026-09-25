import Foundation
import SwiftUI
import Combine
import AetherEngine

@MainActor
final class PlaybackViewModel: ObservableObject {
    @Published private(set) var playbackEngine: AetherPlaybackEngine?
    @Published private(set) var playbackError: String?

    private var tracker: TraktPlaybackTracker?
    private var veyraHubTracker: VeyraHubPlaybackTracker?
    private var recorderCleanupTracker: VeyraHubRecorderCleanupTracker?

    private let source: PlayableSource
    private let item: MediaItem?
    private let resumeProgress: Double?

    // Sommige IPTV/live-TV-bronnen laten de onderliggende netwerkverbinding
    // hangen (time-outs bij de probe/handshake) zonder dat AetherEngine dat
    // ooit als fout naar boven gooit — dat gaf een permanent zwart scherm
    // zonder foutmelding. Met deze timeout krijgt `engine.play(...)` een
    // hard plafond, zodat zo'n hang alsnog als duidelijke afspeelfout
    // eindigt (met retry-knop) in plaats van oneindig te blijven hangen.
    private static let playbackStartTimeout: TimeInterval = 20

    nonisolated init(source: PlayableSource, item: MediaItem?, resumeProgress: Double?) {
        self.source = source
        self.item = item
        self.resumeProgress = resumeProgress
    }

    func startPlayback() async {
        do {
            SubtitleService.shared.reset()

            let engine = try AetherPlaybackEngine()
            playbackEngine = engine

            if let item {
                tracker = TraktPlaybackTracker(item: item, engine: engine.engine)
            }

            if let sync = source.progressSync {
                veyraHubTracker = VeyraHubPlaybackTracker(sync: sync, engine: engine.engine)
            }

            if let cleanup = source.recorderCleanup {
                recorderCleanupTracker = VeyraHubRecorderCleanupTracker(cleanup: cleanup, engine: engine.engine)
            }

            let playSource = source
            let playResumeProgress = await Self.resolveResumeProgress(
                source: source,
                fallback: resumeProgress
            )

            try await Self.withTimeout(seconds: Self.playbackStartTimeout) {
                try await engine.play(playSource, resumeProgress: playResumeProgress)
            }

            try Task.checkCancellation()

            // OpenSubtitles pas ná de hoofdstream
            // toevoegen. Playback hoeft hier niet
            // op te wachten om te starten.
            if let item {
                await SubtitleService.shared.loadExternalSubtitles(for: item, into: engine.engine)
            }

        } catch is CancellationError {
            tracker?.finish()
            veyraHubTracker?.finish()
            recorderCleanupTracker?.finish()
            playbackEngine?.stop()
            SubtitleService.shared.reset()

        } catch {
            tracker?.finish()
            veyraHubTracker?.finish()
            recorderCleanupTracker?.finish()
            playbackEngine?.stop()
            SubtitleService.shared.reset()

            playbackError = error.localizedDescription
        }
    }

    /// Opnieuw proberen na een afspeelfout, zonder het scherm te sluiten.
    func retry() async {
        playbackError = nil
        await startPlayback()
    }

    func stopForDisappear() {
        tracker?.finish()
        veyraHubTracker?.finish()
        recorderCleanupTracker?.finish()
        playbackEngine?.stop()
        SubtitleService.shared.reset()

        tracker = nil
        veyraHubTracker = nil
        recorderCleanupTracker = nil
        playbackEngine = nil
    }

    func handleScenePhaseChange(_ phase: ScenePhase) {
        if phase != .active {
            // Ook bij naar de achtergrond gaan (Home-knop, app wisselen)
            // de kijkvoortgang meteen afronden/versturen, anders blijft
            // de positie hangen op het laatst bekende afspeel-/pauze-event.
            tracker?.finish()
            veyraHubTracker?.finish()
            recorderCleanupTracker?.finish()
            playbackEngine?.stop()
        }
    }

    // MARK: - VeyraHub resume

    /// Prefers VeyraHub's own stored resume position (synced across every
    /// device signed into the same account) over the Trakt-derived
    /// `resumeProgress` this view model was handed, for a source that came
    /// from a VeyraHub server. `AetherPlaybackEngine` expects a 0–100
    /// percentage (see `resolveStartPosition`), so a stored
    /// positionSeconds/durationSeconds pair is converted here rather than
    /// changing that engine-side contract for one source type. Falls back
    /// to `fallback` whenever VeyraHub has no stored position, or the
    /// lookup fails — a resume-position lookup must never block or break
    /// starting playback.
    private static func resolveResumeProgress(
        source: PlayableSource,
        fallback: Double?
    ) async -> Double? {
        guard let sync = source.progressSync else { return fallback }

        do {
            let progress = try await VeyraHubNativeClient(account: sync.account)
                .progress(type: sync.mediaType, id: sync.mediaID)

            guard
                progress.found,
                let position = progress.positionSeconds,
                let duration = progress.durationSeconds,
                duration > 0, position > 0
            else {
                return fallback
            }

            return min(100, max(0, position / duration * 100))
        } catch {
            print("[PlaybackViewModel] VeyraHub resume-opzoeking mislukt: \(error.localizedDescription)")
            return fallback
        }
    }

    // MARK: - Timeout

    private struct PlaybackTimeoutError: LocalizedError {
        var errorDescription: String? {
            "De stream reageert niet. Controleer je internetverbinding of probeer het later opnieuw."
        }
    }

    private static func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw PlaybackTimeoutError()
            }

            defer { group.cancelAll() }

            guard let result = try await group.next() else {
                throw PlaybackTimeoutError()
            }
            return result
        }
    }
}
