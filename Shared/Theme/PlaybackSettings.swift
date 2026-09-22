import Foundation

/// Centrale afspeelinstellingen voor heel Veyra.
///
/// Deze waarden gelden voor:
/// - films
/// - series
/// - afleveringen
/// - Live TV
/// - mediaservers
///
/// Zolang alle playback via dezelfde PlayerView / AetherEngine loopt,
/// worden deze voorkeuren overal hetzelfde toegepast.
enum PlaybackSettingsDefaults {
    // Afspelen
    static let autoRotateLandscapeKey = "playback.autoRotateLandscape"
    static let autoPlayNextEpisodeKey = "playback.autoPlayNextEpisode"
    static let autoSelectFirstSourceKey = "playback.autoSelectFirstSource"
    static let skipContinueWatchingDetailsKey = "playback.skipContinueWatchingDetails"
    static let preferredResolutionKey = "playback.preferredResolution"
    static let cellularResolutionKey = "playback.cellularResolution"

    // Loading screen
    static let hideProgressBarKey = "playback.hideProgressBar"

    // Taal
    static let audioLanguageKey = "playback.audioLanguage"
    static let audioFallbackLanguageKey = "playback.audioFallbackLanguage"
    static let subtitleLanguageKey = "playback.subtitleLanguage"
    static let subtitleFallbackLanguageKey = "playback.subtitleFallbackLanguage"
    static let autoSelectSubtitlesKey = "playback.autoSelectSubtitles"
    static let animeAudioKey = "playback.animeAudio"

    // Oversla-segmenten
    static let showSkipIntroButtonKey = "playback.showSkipIntroButton"
    static let autoSkipIntroKey = "playback.autoSkipIntro"
    static let showSkipRecapButtonKey = "playback.showSkipRecapButton"
    static let showSkipCreditsButtonKey = "playback.showSkipCreditsButton"
    static let postCreditsAlertKey = "playback.postCreditsAlert"

    // Hierna
    static let autoPlayNextCountdownEnabledKey = "playback.autoPlayNextCountdownEnabled"
    static let countdownDurationKey = "playback.countdownDuration"

    // Speler
    static let selectedPlayerKey = "playback.selectedPlayer"
}

enum PlaybackResolutionOption: String, CaseIterable, Identifiable {
    case highest
    case uhd4K
    case fullHD1080
    case hd720

    var id: String { rawValue }

    var title: String {
        switch self {
        case .highest:
            return "Highest Available"

        case .uhd4K:
            return "4K"

        case .fullHD1080:
            return "1080p"

        case .hd720:
            return "720p"
        }
    }
}

enum PlaybackCellularResolutionOption: String, CaseIterable, Identifiable {
    case highest
    case fullHD1080
    case hd720
    case sd480

    var id: String { rawValue }

    var title: String {
        switch self {
        case .highest:
            return "Highest Available"

        case .fullHD1080:
            return "1080p Max"

        case .hd720:
            return "720p Max"

        case .sd480:
            return "480p Max"
        }
    }
}

/// Centrale taalkeuze voor heel Veyra.
///
/// `rawValue` blijft hetzelfde als in de bestaande instellingen.
/// Daardoor blijven eerder opgeslagen keuzes geldig.
enum PlaybackLanguageOption: String, CaseIterable, Identifiable {
    case original
    case dutch
    case english
    case french
    case german
    case spanish

    var id: String { rawValue }

    var title: String {
        switch self {
        case .original:
            return "Original Language"

        case .dutch:
            return "Dutch"

        case .english:
            return "English"

        case .french:
            return "French"

        case .german:
            return "German"

        case .spanish:
            return "Spanish"
        }
    }

    /// ISO 639-1, ISO 639-2 en veelgebruikte varianten die
    /// mediaservers/containers kunnen teruggeven.
    var languageCodes: Set<String> {
        switch self {
        case .original:
            return []

        case .dutch:
            return [
                "nl",
                "nld",
                "dut",
                "nl-nl",
                "nl-be"
            ]

        case .english:
            return [
                "en",
                "eng",
                "en-us",
                "en-gb",
                "en-au",
                "en-ca"
            ]

        case .french:
            return [
                "fr",
                "fra",
                "fre",
                "fr-fr",
                "fr-be",
                "fr-ca"
            ]

        case .german:
            return [
                "de",
                "deu",
                "ger",
                "de-de",
                "de-at",
                "de-ch"
            ]

        case .spanish:
            return [
                "es",
                "spa",
                "es-es",
                "es-mx",
                "es-ar"
            ]
        }
    }

    /// Namen die gebruikt worden wanneer een stream geen correcte
    /// ISO-taalcode bevat maar wel een bruikbare tracknaam.
    private var languageNames: [String] {
        switch self {
        case .original:
            return []

        case .dutch:
            return [
                "dutch",
                "nederlands",
                "nederlandse",
                "vlaams",
                "flemish"
            ]

        case .english:
            return [
                "english",
                "engels",
                "engelse"
            ]

        case .french:
            return [
                "french",
                "français",
                "francais",
                "frans",
                "franse"
            ]

        case .german:
            return [
                "german",
                "deutsch",
                "duits",
                "duitse"
            ]

        case .spanish:
            return [
                "spanish",
                "español",
                "espanol",
                "spaans",
                "spaanse"
            ]
        }
    }

    /// Controleert een audiotrack of ondertiteltrack.
    ///
    /// Eerst wordt de echte taalcode gecontroleerd.
    /// Alleen als fallback wordt ook de tracknaam bekeken.
    func matches(
        languageCode: String?,
        trackName: String?
    ) -> Bool {
        guard self != .original else {
            return false
        }

        if let languageCode {
            let normalized =
                Self.normalizeLanguageCode(
                    languageCode
                )

            if languageCodes.contains(
                normalized
            ) {
                return true
            }

            let base =
                normalized
                    .split(separator: "-")
                    .first
                    .map(String.init)

            if let base,
               languageCodes.contains(base)
            {
                return true
            }
        }

        if let trackName {
            let normalizedName =
                trackName
                    .folding(
                        options: [
                            .diacriticInsensitive,
                            .caseInsensitive
                        ],
                        locale: .current
                    )
                    .lowercased()

            for name in languageNames {
                let normalizedCandidate =
                    name
                        .folding(
                            options: [
                                .diacriticInsensitive,
                                .caseInsensitive
                            ],
                            locale: .current
                        )
                        .lowercased()

                if normalizedName.contains(
                    normalizedCandidate
                ) {
                    return true
                }
            }
        }

        return false
    }

    private static func normalizeLanguageCode(
        _ value: String
    ) -> String {
        value
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .replacingOccurrences(
                of: "_",
                with: "-"
            )
            .lowercased()
    }
}

enum PlaybackAutoSelectSubtitlesOption:
    String,
    CaseIterable,
    Identifiable
{
    case off
    case forcedOnly
    case full

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off:
            return "Off"

        case .forcedOnly:
            return "Forced Only"

        case .full:
            return "Full Subtitles"
        }
    }
}

enum PlaybackAnimeAudioOption:
    String,
    CaseIterable,
    Identifiable
{
    case noPreference
    case sub
    case dub

    var id: String { rawValue }

    var title: String {
        switch self {
        case .noPreference:
            return "No Preference"

        case .sub:
            return "Sub"

        case .dub:
            return "Dub"
        }
    }
}

enum PlaybackCountdownDuration:
    String,
    CaseIterable,
    Identifiable
{
    case five
    case ten
    case fifteen
    case twenty

    var id: String { rawValue }

    var seconds: Int {
        switch self {
        case .five:
            return 5

        case .ten:
            return 10

        case .fifteen:
            return 15

        case .twenty:
            return 20
        }
    }

    var title: String {
        "\(seconds) seconden"
    }
}

enum PlaybackSelectedPlayer:
    String,
    CaseIterable,
    Identifiable
{
    case intern
    case extern

    var id: String { rawValue }

    var title: String {
        switch self {
        case .intern:
            return "Intern"

        case .extern:
            return "Extern"
        }
    }
}
