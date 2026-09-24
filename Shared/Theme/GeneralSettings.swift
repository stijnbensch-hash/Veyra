import SwiftUI

/// Algemene Veyra-voorkeuren: wat er op het startscherm verschijnt (Verder
/// kijken / Binnenkort), hoe posters worden opgemaakt, sportweergave en
/// tekstgrootte.
///
/// Status: waar mogelijk is dit ECHTE functionaliteit (zie de doc-comments
/// per instelling hieronder) — niet alles is een stub, in tegenstelling tot
/// eerdere secties deze sessie. Wat nog niet werkt staat er expliciet bij.
enum GeneralSettingsDefaults {
    // Beginschermplanken
    static let showContinueWatchingKey = "general.showContinueWatching"
    static let continueWatchingLimitKey = "general.continueWatchingLimit"
    static let hideContinueWatchingReleaseDateKey = "general.hideContinueWatchingReleaseDate"
    static let showUpcomingKey = "general.showUpcoming"
    static let includeWatchlistPremieresKey = "general.includeWatchlistPremieresInUpcoming"

    // Posters
    static let showReleaseYearKey = "general.showReleaseYear"
    static let hideTitlesUnderPostersKey = "general.hideTitlesUnderPosters"
    static let hideEpisodesRemainingKey = "general.hideEpisodesRemaining"

    // Sport
    static let hideScoreSpoilersKey = "general.hideScoreSpoilers"
    static let chooseChannelOnTapKey = "general.chooseChannelOnTap"

    // Weergave
    static let textSizeKey = "general.textSize"

    // iPad-navigatie
    static let ipadNavigationStyleKey = "general.ipadNavigationStyle"
}

/// Hoe de hoofdnavigatie op iPad (brede/regular schermbreedte) wordt
/// getoond — als vaste keuze in plaats van het door het systeem geboden
/// wissel-knopje tussen beide weergaven (`.sidebarAdaptable` laat anders
/// altijd omschakelen), zodat er maar één van de twee tegelijk te zien is.
enum IPadNavigationStyle: String, CaseIterable, Identifiable {
    case sidebar
    case topBar

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sidebar: return "Zijbalk"
        case .topBar: return "Menubalk boven"
        }
    }
}

enum GeneralTextSize: String, CaseIterable, Identifiable {
    case small, defaultSize, medium, large, extraLarge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .small: return "Klein"
        case .defaultSize: return "Standaard"
        case .medium: return "Middel"
        case .large: return "Groot"
        case .extraLarge: return "Extra groot"
        }
    }

    /// De dichtstbijzijnde systeem-tekstgrootte. Veyra gebruikt op de meeste
    /// plekken vaste pixelgroottes (`VeyraTypography` e.a. `.system(size:)`
    /// waarden) in plaats van de systeem-tekststijlen, dus deze instelling
    /// heeft alleen effect op tekst die wél Dynamic Type volgt — niet op de
    /// meeste titels, koppen en poster-bijschriften in de app.
    var dynamicTypeSize: DynamicTypeSize {
        switch self {
        case .small: return .small
        case .defaultSize: return .large
        case .medium: return .xLarge
        case .large: return .xxLarge
        case .extraLarge: return .xxxLarge
        }
    }
}
