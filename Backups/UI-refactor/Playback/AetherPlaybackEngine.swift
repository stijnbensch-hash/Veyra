import Foundation
import AetherEngine

@MainActor
final class AetherPlaybackEngine:
    PlaybackEngine
{
    let engine: AetherEngine

    init() throws {
        engine = try AetherEngine()
    }

    func play(
        _ source: PlayableSource
    ) async throws {
        try await play(
            source,
            resumeProgress: nil
        )
    }

    func play(
        _ source: PlayableSource,
        resumeProgress: Double?
    ) async throws {
        var options = LoadOptions()

        if source.requiresSoftwareVideo {
            options.preferredDecodePath =
                .software
        } else {
            options.preferredDecodePath =
                .automatic
        }

        // Nederlandse embedded subtitles krijgen
        // voorrang wanneer ze in de stream bestaan.
        options.preferredSubtitleLanguages = [
            "nl",
            "nld",
            "dut",
            "en"
        ]

        // Zorgt ervoor dat Aether subtitletracks
        // volledig voorbereidt tijdens het laden.
        options.prepareNativeSubtitles =
            true

        // Stream URLs kunnen providercredentials
        // bevatten; log daarom nooit de URL zelf.
        print(
            "[Veyra] Software video:",
            source.requiresSoftwareVideo
        )

        try await engine.load(
            url: source.url,
            options: options
        )

        print(
            "[Veyra] State after load:",
            engine.state
        )

        try Task
            .checkCancellation()

        if
            let progress =
                resumeProgress,
            progress.isFinite,
            progress > 0,
            progress < 100,
            engine.duration.isFinite,
            engine.duration > 0
        {
            await engine.seek(
                to:
                    engine.duration
                    * progress
                    / 100
            )

            try Task
                .checkCancellation()
        }

        engine.play()

        print(
            "[Veyra] State after play:",
            engine.state
        )
    }

    func stop() {
        engine.pause()
    }
}
