import SwiftUI
import AetherEngine

struct PlayerView: View {
    let source: PlayableSource

    @State private var playbackEngine: AetherPlaybackEngine?
    @State private var playbackError: String?

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if let playbackEngine {
                AetherPlayerSurface(
                    engine: playbackEngine.engine
                )
                .ignoresSafeArea()
            } else if let playbackError {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))

                    Text("Afspelen niet mogelijk")
                        .font(.title)

                    Text(playbackError)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            } else {
                VStack(spacing: 16) {
                    ProgressView()

                    Text("Veyra Player starten…")
                        .font(.title3)
                }
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

            try await engine.play(source)
        } catch {
            playbackError = error.localizedDescription
        }
    }
}
