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

        Self.applyPreferredAudioTrack(engine)
        Self.applyPreferredSubtitleTrack(engine)
    }

    func stop() {
        engine.stop()
    }

    // MARK: - Taal

    /// Selecteert automatisch de audiotrack die overeenkomt met de
    /// "Afspelen \u2192 Taal"-instellingen (primaire/terugval-audiotaal).
    /// "Original Language" laat de standaardtrack van de bron ongemoeid.
    private static func applyPreferredAudioTrack(_ engine: AetherEngine) {
        guard !engine.audioTracks.isEmpty else { return }

        let defaults = UserDefaults.standard

        let primary = PlaybackLanguageOption(
            rawValue: defaults.string(forKey: PlaybackSettingsDefaults.audioLanguageKey)
                ?? PlaybackLanguageOption.original.rawValue
        ) ?? .original

        guard primary != .original else { return }

        if let match = engine.audioTracks.first(where: {
            primary.matches(languageCode: $0.language, trackName: $0.name)
        }) {
            engine.selectAudioTrack(index: match.id)
            return
        }

        let fallback = PlaybackLanguageOption(
            rawValue: defaults.string(forKey: PlaybackSettingsDefaults.audioFallbackLanguageKey)
                ?? PlaybackLanguageOption.english.rawValue
        ) ?? .english

        guard fallback != .original,
              let fallbackMatch = engine.audioTracks.first(where: {
                  fallback.matches(languageCode: $0.language, trackName: $0.name)
              })
        else { return }

        engine.selectAudioTrack(index: fallbackMatch.id)
    }

    /// Selecteert automatisch de ondertiteltrack die overeenkomt met de
    /// "Afspelen \u2192 Taal"-instellingen (primaire/terugval-ondertiteltaal),
    /// als aanvulling op `LoadOptions.preferredSubtitleLanguages`: die hint
    /// alleen doorgeven aan de engine bleek in de praktijk niet te leiden tot
    /// een automatisch geselecteerde track, dus hier wordt expliciet dezelfde
    /// track-matching als bij audio toegepast zodra de tracks bekend zijn.
    private static func applyPreferredSubtitleTrack(_ engine: AetherEngine) {
        guard !engine.subtitleTracks.isEmpty else { return }

        let defaults = UserDefaults.standard

        let autoSelect = PlaybackAutoSelectSubtitlesOption(
            rawValue: defaults.string(forKey: PlaybackSettingsDefaults.autoSelectSubtitlesKey)
                ?? PlaybackAutoSelectSubtitlesOption.forcedOnly.rawValue
        ) ?? .forcedOnly

        guard autoSelect != .off else { return }

        let candidates =
            autoSelect == .forcedOnly
            ? engine.subtitleTracks.filter { $0.isForced }
            : engine.subtitleTracks

        guard !candidates.isEmpty else { return }

        let primary = PlaybackLanguageOption(
            rawValue: defaults.string(forKey: PlaybackSettingsDefaults.subtitleLanguageKey)
                ?? PlaybackLanguageOption.dutch.rawValue
        ) ?? .dutch

        if let match = candidates.first(where: {
            primary.matches(languageCode: $0.language, trackName: $0.name)
        }) {
            engine.selectSubtitleTrack(index: match.id)
            return
        }

        let fallback = PlaybackLanguageOption(
            rawValue: defaults.string(forKey: PlaybackSettingsDefaults.subtitleFallbackLanguageKey)
                ?? PlaybackLanguageOption.english.rawValue
        ) ?? .english

        guard
            let fallbackMatch = candidates.first(where: {
                fallback.matches(languageCode: $0.language, trackName: $0.name)
            })
        else { return }

        engine.selectSubtitleTrack(index: fallbackMatch.id)
    }

    // MARK: - Load options

    private func makeLoadOptions(
        for source:
            PlayableSource
    ) -> LoadOptions {
        var options =
            LoadOptions()

        // Live IPTV-kanalen zijn oneindige, niet-seekbare .ts-streams
        // zonder geldige Content-Length/Range-ondersteuning. Zonder
        // `isLive` behandelt AetherEngine ze als VOD en doet het eerst
        // HTTP HEAD-/Range-probes om de duur/seekbaarheid te bepalen —
        // iets wat veel Xtream live-origins niet netjes beantwoorden
        // (soms HTTP 502, soms een timeout, soms lukt de forward-only
        // terugval toch nog). Met `isLive = true` slaat de engine die
        // probes voor live-kanalen meteen over en gaat hij direct
        // forward-only streamen, zoals andere IPTV-spelers al deden.
        options.isLive =
            source.kind == .liveTV

        if source.requiresSoftwareVideo {
            options.preferredDecodePath =
                .software

        } else {
            options.preferredDecodePath =
                .automatic
        }

        options.preferredSubtitleLanguages = Self.preferredSubtitleLanguageCodes()

        // Embedded subtitletracks al tijdens
        // het laden voorbereiden.
        options.prepareNativeSubtitles =
            true

        return options
    }

    /// Bepaalt welke taalcodes de engine mag gebruiken om bij het laden
    /// automatisch een ingebouwde ondertitel te selecteren, op basis van
    /// de "Afspelen \u2192 Taal"-instellingen (`PlaybackSettingsDefaults`).
    /// Bij "Uit" wordt niets automatisch geselecteerd. Anders worden de
    /// primaire en terugval-taal gecombineerd met de bestaande
    /// ondertitel-weergavevoorkeur (`SubtitlePreferences`), zodat een
    /// eerder gekozen standaardtaal daar blijft werken.
    private static func preferredSubtitleLanguageCodes() -> [String] {
        let defaults = UserDefaults.standard

        let autoSelect = PlaybackAutoSelectSubtitlesOption(
            rawValue: defaults.string(forKey: PlaybackSettingsDefaults.autoSelectSubtitlesKey)
                ?? PlaybackAutoSelectSubtitlesOption.forcedOnly.rawValue
        ) ?? .forcedOnly

        guard autoSelect != .off else { return [] }

        let primary = PlaybackLanguageOption(
            rawValue: defaults.string(forKey: PlaybackSettingsDefaults.subtitleLanguageKey)
                ?? PlaybackLanguageOption.dutch.rawValue
        ) ?? .dutch

        let fallback = PlaybackLanguageOption(
            rawValue: defaults.string(forKey: PlaybackSettingsDefaults.subtitleFallbackLanguageKey)
                ?? PlaybackLanguageOption.english.rawValue
        ) ?? .english

        var codes: [String] = []
        codes.append(contentsOf: primary.languageCodes)
        codes.append(contentsOf: fallback.languageCodes)
        codes.append(contentsOf: SubtitlePreferences.language().codes)

        var seen = Set<String>()
        return codes.filter { seen.insert($0).inserted }
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
