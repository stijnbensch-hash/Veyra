import SwiftUI
import AetherEngine

struct PlayerView: View {
    let source: PlayableSource

    var item: MediaItem? = nil

    var resumeProgress:
        Double? = nil

    @Environment(\.scenePhase)
    private var scenePhase

    @State
    private var tracker:
        TraktPlaybackTracker?

    @State
    private var playbackEngine:
        AetherPlaybackEngine?

    @State
    private var playbackError:
        String?

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if let playbackError {
                VStack(
                    spacing: 20
                ) {
                    Text(
                        "Afspelen niet mogelijk"
                    )
                    .font(
                        .system(
                            size: 34,
                            weight: .bold
                        )
                    )

                    Text(
                        playbackError
                    )
                    .foregroundStyle(
                        .secondary
                    )
                    .font(
                        .system(
                            size: 22
                        )
                    )
                }
                .padding(50)

            } else if let playbackEngine {
                AetherPlayerSurface(
                    engine:
                        playbackEngine.engine
                )
                .ignoresSafeArea()

                PlayerSubtitleControls(
                    engine:
                        playbackEngine.engine
                )
                .ignoresSafeArea()

            } else {
                VStack(
                    spacing: 16
                ) {
                    ProgressView()

                    Text(
                        "Veyra Player starten…"
                    )
                    .font(
                        .system(
                            size: 26
                        )
                    )
                }
            }
        }
        .task {
            await startPlayback()
        }
        .onDisappear {
            tracker?.finish()

            playbackEngine?
                .stop()

            SubtitleService
                .shared
                .reset()

            tracker = nil

            playbackEngine =
                nil
        }
        .onChange(
            of: scenePhase
        ) { _, phase in
            if phase != .active {
                playbackEngine?
                    .stop()
            }
        }
    }

    @MainActor
    private func startPlayback()
        async
    {
        do {
            SubtitleService
                .shared
                .reset()

            let engine =
                try AetherPlaybackEngine()

            playbackEngine =
                engine

            if let item {
                tracker =
                    TraktPlaybackTracker(
                        item: item,
                        engine:
                            engine.engine
                    )
            }

            try await engine.play(
                source,
                resumeProgress:
                    resumeProgress
            )

            try Task
                .checkCancellation()

            // OpenSubtitles pas ná de hoofdstream
            // toevoegen. Playback hoeft hier niet
            // op te wachten om te starten.
            if let item {
                await SubtitleService
                    .shared
                    .loadExternalSubtitles(
                        for: item,
                        into:
                            engine.engine
                    )
            }

        } catch is CancellationError {
            tracker?.finish()

            playbackEngine?
                .stop()

            SubtitleService
                .shared
                .reset()

        } catch {
            tracker?.finish()

            playbackEngine?
                .stop()

            SubtitleService
                .shared
                .reset()

            playbackError =
                error.localizedDescription
        }
    }
}
