import Foundation
import AetherEngine

@MainActor
final class AetherPlaybackEngine:
    PlaybackEngine
{
    let engine: AetherEngine

    init() throws {
        engine =
            try AetherEngine()
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
        let options =
            makeLoadOptions(
                for: source
            )

        let startPosition =
            await resolveStartPosition(
                for: source,
                resumeProgress:
                    resumeProgress
            )

        try Task
            .checkCancellation()

        print(
            "[Veyra] Software video:",
            source.requiresSoftwareVideo
        )

        if let startPosition {
            print(
                "[Veyra] Resume via Aether startPosition:",
                startPosition
            )

            // Belangrijk:
            // Aether krijgt de hervatpositie meteen
            // tijdens het openen van de mediasessie.
            //
            // Niet eerst openen en daarna seeken.
            try await engine.load(
                url: source.url,
                startPosition:
                    startPosition,
                options:
                    options
            )

        } else {
            try await engine.load(
                url: source.url,
                options:
                    options
            )
        }

        try Task
            .checkCancellation()

        print(
            "[Veyra] State after load:",
            engine.state
        )

        print(
            "[Veyra] Duration:",
            engine.duration
        )

        print(
            "[Veyra] Current time after load:",
            engine.currentTime
        )

        engine.play()

        print(
            "[Veyra] State after play:",
            engine.state
        )
    }

    func stop() {
        engine.stop()
    }

    // MARK: - Load options

    private func makeLoadOptions(
        for source:
            PlayableSource
    ) -> LoadOptions {
        var options =
            LoadOptions()

        if source.requiresSoftwareVideo {
            options.preferredDecodePath =
                .software

        } else {
            options.preferredDecodePath =
                .automatic
        }

        options.preferredSubtitleLanguages = SubtitlePreferences.language().codes

        // Embedded subtitletracks al tijdens
        // het laden voorbereiden.
        options.prepareNativeSubtitles =
            true

        return options
    }

    // MARK: - Resume

    private func resolveStartPosition(
        for source:
            PlayableSource,
        resumeProgress:
            Double?
    ) async -> Double? {
        guard
            let progress =
                validResumeProgress(
                    resumeProgress
                )
        else {
            return nil
        }

        print(
            "[Veyra] Trakt resume progress:",
            progress
        )

        do {
            let url =
                source.url

            // Aether probe is synchroon.
            // Daarom buiten de MainActor uitvoeren,
            // zodat de tvOS-interface niet blokkeert
            // tijdens netwerk/containeranalyse.
            let probe =
                try await Task.detached(
                    priority:
                        .userInitiated
                ) {
                    try AetherEngine.probe(
                        url: url
                    )
                }
                .value

            try Task
                .checkCancellation()

            let duration =
                probe.durationSeconds

            guard
                duration.isFinite,
                duration > 0
            else {
                print(
                    "[Veyra] Resume skipped: probe returned no usable duration"
                )

                return nil
            }

            let position =
                resumePosition(
                    progress:
                        progress,
                    duration:
                        duration
                )

            guard
                position > 0
            else {
                return nil
            }

            print(
                "[Veyra] Probe duration:",
                duration
            )

            print(
                "[Veyra] Resume position:",
                position
            )

            return position

        } catch is CancellationError {
            return nil

        } catch {
            // Een mislukte probe mag normaal
            // afspelen nooit blokkeren.
            //
            // In dat geval starten we gewoon
            // vanaf het begin.
            print(
                "[Veyra] Resume probe failed:",
                error.localizedDescription
            )

            return nil
        }
    }

    private func validResumeProgress(
        _ progress:
            Double?
    ) -> Double? {
        guard
            let progress,
            progress.isFinite,
            progress > 0,
            progress < 100
        else {
            return nil
        }

        return progress
    }

    private func resumePosition(
        progress: Double,
        duration: Double
    ) -> Double {
        let rawPosition =
            duration
            * progress
            / 100

        // Niet exact bij het einde openen.
        // Hierdoor kan een Trakt-positie vlak
        // voor 100% de mediasessie niet meteen
        // als voltooid laten eindigen.
        let maximumPosition =
            max(
                0,
                duration - 10
            )

        return min(
            max(
                rawPosition,
                0
            ),
            maximumPosition
        )
    }
}
