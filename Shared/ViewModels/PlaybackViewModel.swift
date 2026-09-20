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

            try await engine.play(source, resumeProgress: resumeProgress)

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
}
