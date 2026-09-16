import Foundation
import AetherEngine

@MainActor
final class AetherPlaybackEngine: PlaybackEngine {
    let engine: AetherEngine

    init() throws {
        engine = try AetherEngine()
    }

    func play(_ source: PlayableSource) async throws {
        try await engine.load(url: source.url)
        engine.play()
    }

    func stop() {
        engine.pause()
    }
}
