import Foundation

/// Live TV-voorkeuren van Veyra: gidsvormgeving, welke motor live-zenders
/// afspeelt, buffering/catch-up-correctie, en hoe vaak zenderlijst en gids
/// ververst worden.
///
/// Status: dit bestand legt alleen de instellingen zelf vast (opslag +
/// keuzelijsten). Er bestaat vandaag geen zenderlijst- of gidscache in
/// Veyra, geen aparte afspeelmotor-keuze voor Live TV, en geen FPS-teller —
/// dus niets hiervan heeft nu al effect. De instellingen staan klaar zodat
/// ze aangesloten kunnen worden zodra die onderdelen gebouwd zijn.
enum IPTVPlaybackSettingsDefaults {
    // Zenderguide
    static let guideThemeKey = "iptv.guideTheme"
    static let hideCountryPrefixKey = "iptv.hideCountryPrefix"

    // Afspeelmotor
    static let playerEngineKey = "iptv.playerEngine"

    // Buffering & catch-up
    static let bufferDurationKey = "iptv.bufferDuration"
    static let catchUpOffsetModeKey = "iptv.catchUpOffsetMode"
    static let catchUpOffsetManualSecondsKey = "iptv.catchUpOffsetManualSeconds"

    // Cache & verversen
    static let refreshChannelsIntervalKey = "iptv.refreshChannelsInterval"
    static let refreshEPGIntervalKey = "iptv.refreshEPGInterval"

    // Ontwikkelaarsopties
    static let showFPSCounterKey = "iptv.showFPSCounter"
}

enum IPTVGuideTheme: String, CaseIterable, Identifiable {
    case colourful, grey, black
    var id: String { rawValue }
    var title: String {
        switch self {
        case .colourful: return "Kleurrijk"
        case .grey: return "Grijstinten"
        case .black: return "Zwart"
        }
    }
}

enum IPTVPlayerEngineOption: String, CaseIterable, Identifiable {
    case intern, avPlayer
    var id: String { rawValue }
    var title: String {
        switch self {
        case .intern: return "Veyra-speler"
        case .avPlayer: return "AVPlayer (systeem)"
        }
    }
}

enum IPTVBufferDurationOption: String, CaseIterable, Identifiable {
    case none, oneSecond, twoSeconds, fiveSeconds, tenSeconds
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: return "Geen"
        case .oneSecond: return "1 seconde"
        case .twoSeconds: return "2 seconden"
        case .fiveSeconds: return "5 seconden"
        case .tenSeconds: return "10 seconden"
        }
    }
}

enum IPTVCatchUpOffsetMode: String, CaseIterable, Identifiable {
    case automatic, manual
    var id: String { rawValue }
    var title: String {
        switch self {
        case .automatic: return "Automatisch"
        case .manual: return "Handmatig"
        }
    }
}

enum IPTVCacheRefreshInterval: String, CaseIterable, Identifiable {
    case oneHour, threeHours, sixHours, twelveHours, twentyFourHours, never
    var id: String { rawValue }
    var title: String {
        switch self {
        case .oneHour: return "1 uur"
        case .threeHours: return "3 uur"
        case .sixHours: return "6 uur"
        case .twelveHours: return "12 uur"
        case .twentyFourHours: return "24 uur"
        case .never: return "Nooit"
        }
    }
}
