import Foundation
import SwiftUI
import Combine
import AetherEngine

@MainActor
final class PlaybackViewModel: ObservableObject {
    @Published private(set) var playbackEngine: AetherPlaybackEngine?
    @Published private(set) var playbackError: String?

    private var tracker: TraktPlaybackTracker?

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

            let playSource = source
            let playResumeProgress = resumeProgress

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
            playbackEngine?.stop()
            SubtitleService.shared.reset()

        } catch {
            tracker?.finish()
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
        playbackEngine?.stop()
        SubtitleService.shared.reset()

        tracker = nil
        playbackEngine = nil
    }

    func handleScenePhaseChange(_ phase: ScenePhase) {
        if phase != .active {
            // Ook bij naar de achtergrond gaan (Home-knop, app wisselen)
            // de kijkvoortgang meteen afronden/versturen, anders blijft
            // de positie hangen op het laatst bekende afspeel-/pauze-event.
            tracker?.finish()
            playbackEngine?.stop()
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
