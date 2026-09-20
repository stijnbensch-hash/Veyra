import Foundation

/// "Afspelen"-instellingen, zoals Strand die aanbiedt: automatisch draaien,
/// resolutie, ondertitel- en audiotaal, oversla-segmenten, automatisch
/// doorspelen en spelerkeuze.
///
/// HDR en Dolby Vision hebben hier bewust geen instelling: `AetherEngine`
/// herkent en schakelt daar zelf automatisch naar over (zie z'n eigen
/// `VideoFormat`/`DolbyVisionConversion`), dus daar is niets voor Veyra om
/// aan te sturen.
///
/// Status van de rest: "Volgende aflevering automatisch afspelen", de
/// aftel-instellingen ("Hierna") en de oversla-knoppen voor intro/recap/
/// aftiteling sturen de speler inmiddels wél aan. De overige instellingen
/// (resolutielimieten, taalvoorkeuren, spelerkeuze) leggen nog alleen
/// opslag + keuzelijsten vast — `AetherEngine` zit niet in dit
/// project-exemplaar, dus of en hoe die bv. resolutielimieten of een
/// externe speler ondersteunt, is hier niet te verifiëren.
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
    case highest, uhd4K, fullHD1080, hd720

    var id: String { rawValue }

    var title: String {
        switch self {
        case .highest: return "Highest Available"
        case .uhd4K: return "4K"
        case .fullHD1080: return "1080p"
        case .hd720: return "720p"
        }
    }
}

enum PlaybackCellularResolutionOption: String, CaseIterable, Identifiable {
    case highest, fullHD1080, hd720, sd480

    var id: String { rawValue }

    var title: String {
        switch self {
        case .highest: return "Highest Available"
        case .fullHD1080: return "1080p Max"
        case .hd720: return "720p Max"
        case .sd480: return "480p Max"
        }
    }
}

/// Kleine, op zichzelf staande taallijst voor deze Afspelen-instellingen.
/// Bewust niet gedeeld met de bestaande Ondertitels-standaardtaal, om geen
/// aannames te doen over een type dat niet in dit project-exemplaar zit.
enum PlaybackLanguageOption: String, CaseIterable, Identifiable {
    case original, dutch, english, french, german, spanish

    var id: String { rawValue }

    var title: String {
        switch self {
        case .original: return "Original Language"
        case .dutch: return "Dutch"
        case .english: return "English"
        case .french: return "French"
        case .german: return "German"
        case .spanish: return "Spanish"
        }
    }
}

enum PlaybackAutoSelectSubtitlesOption: String, CaseIterable, Identifiable {
    case off, forcedOnly, full

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: return "Off"
        case .forcedOnly: return "Forced Only"
        case .full: return "Full Subtitles"
        }
    }
}

enum PlaybackAnimeAudioOption: String, CaseIterable, Identifiable {
    case noPreference, sub, dub

    var id: String { rawValue }

    var title: String {
        switch self {
        case .noPreference: return "No Preference"
        case .sub: return "Sub"
        case .dub: return "Dub"
        }
    }
}

enum PlaybackCountdownDuration: String, CaseIterable, Identifiable {
    case five, ten, fifteen, twenty

    var id: String { rawValue }

    var seconds: Int {
        switch self {
        case .five: return 5
        case .ten: return 10
        case .fifteen: return 15
        case .twenty: return 20
        }
    }

    var title: String { "\(seconds) seconden" }
}

enum PlaybackSelectedPlayer: String, CaseIterable, Identifiable {
    case intern, extern

    var id: String { rawValue }

    var title: String {
        switch self {
        case .intern: return "Intern"
        case .extern: return "Extern"
        }
    }
}
