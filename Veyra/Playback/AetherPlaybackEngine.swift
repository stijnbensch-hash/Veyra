import Foundation
import AetherEngine

@MainActor
final class AetherPlaybackEngine: PlaybackEngine {
    let engine: AetherEngine

    init() throws {
        engine = try AetherEngine()
    }

    func play(_ source: PlayableSource) async throws {
        var options = LoadOptions()

        if source.requiresSoftwareVideo {
            options.preferredDecodePath = .software
        } else {
            options.preferredDecodePath = .automatic
        }

        print("[Veyra] Loading:", source.url.absoluteString)
        print("[Veyra] Software video:", source.requiresSoftwareVideo)

        try await engine.load(
            url: source.url,
            options: options
        )

        print("[Veyra] State after load:", engine.state)

        engine.play()

        print("[Veyra] State after play:", engine.state)
    }

    func stop() {
        engine.pause()
    }
}
