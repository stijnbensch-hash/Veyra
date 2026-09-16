import SwiftUI
import AetherEngine

struct PlaybackTestView: View {
    @State private var playbackEngine: AetherPlaybackEngine?

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if let playbackEngine {
                PlayerView(engine: playbackEngine.engine)
            } else {
                ProgressView("Starting Veyra Player…")
            }
        }
        .task {
            await startPlayback()
        }
    }

    @MainActor
    private func startPlayback() async {
        do {
            let engine = try AetherPlaybackEngine()
            playbackEngine = engine

            let source = PlayableSource(
                name: "Veyra Test Video",
                url: URL(
                    string: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"
                )!,
                kind: .direct
            )

            try await engine.play(source)
        } catch {
            print("Veyra playback error:", error)
        }
    }
}
