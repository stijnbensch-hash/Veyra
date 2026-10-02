// TMDBImageURLBuilder.swift — gedeeld (tvOS/iOS/iPadOS/macOS)
// Fase 5 ("VEYRA — TMDB PERFORMANCE & CACHING REFACTOR" spec §21/§22/§23): één centrale plek
// voor TMDB-afbeeldings-URL's i.p.v. de ~10 bestanden die elk hun eigen
// "https://image.tmdb.org/t/p/\(size)\(path)"-string bouwden, soms met `original` waar een
// kleine vaste maat ruim voldoende is (zie `WatchProviders.swift` vóór deze Fase).
//
// De exacte beschikbare TMDB-maten komen normaal uit `/configuration` (spec §20, al gecached
// door `TMDBRequestCoordinator.configuration(token:)` sinds Fase 2) -- maar elke aanroeper hier
// is een gewone synchrone functie (posterURL/backdropURL enz. worden overal synchroon ingevuld
// bij het opbouwen van een `MediaItem`, niet pas async bij het renderen). De onderstaande maten
// zijn TMDB's eigen, al jarenlang stabiele standaardlijst -- geen gok, maar wél hardcoded zolang
// er geen synchroon toegankelijke, vooraf geladen configuratie bestaat.

import Foundation

enum TMDBImageKind {
    case poster
    case backdrop
    case profile
    case logo
}

/// Semantische grootte i.p.v. een losse size-string per aanroepplek (spec §23/§24: "kleine
/// poster → w342", "grote backdrop → w1280", ...).
enum TMDBImageVariant {
    /// Klein: posterrooster/avatar/logo-badge.
    case small
    /// Normaal: standaard kaart/poster.
    case normal
    /// Groot: gefocuste kaart, detailscherm-poster.
    case large
    /// Hero/fullscreen: backdrop-hero, grote achtergrond.
    case hero
}

enum TMDBImageURLBuilder {
    private static let baseURL = "https://image.tmdb.org/t/p/"

    private static func size(for kind: TMDBImageKind, variant: TMDBImageVariant) -> String {
        switch (kind, variant) {
        case (.poster, .small): return "w185"
        case (.poster, .normal): return "w342"
        case (.poster, .large): return "w500"
        case (.poster, .hero): return "w780"
        case (.backdrop, .small): return "w300"
        case (.backdrop, .normal): return "w780"
        case (.backdrop, .large): return "w1280"
        case (.backdrop, .hero): return "w1280"
        case (.profile, .small): return "w45"
        case (.profile, .normal), (.profile, .large), (.profile, .hero): return "w185"
        case (.logo, .small): return "w92"
        case (.logo, .normal): return "w154"
        case (.logo, .large), (.logo, .hero): return "w300"
        }
    }

    static func url(path: String?, kind: TMDBImageKind, variant: TMDBImageVariant) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        let normalizedPath = path.hasPrefix("/") ? path : "/" + path
        return URL(string: baseURL + size(for: kind, variant: variant) + normalizedPath)
    }

    /// Standaard "gewone kaart"-grootte (w500) -- expliciet `variant` meegeven voor een
    /// posterrooster (`.small`) of een gefocuste/detail-poster (`.large`).
    static func poster(_ path: String?, variant: TMDBImageVariant = .normal) -> URL? {
        url(path: path, kind: .poster, variant: variant)
    }

    /// Standaard grote achtergrond (w1280) -- de meeste backdrops in Veyra zijn hero's/volledige
    /// achtergronden, vandaar `.hero` als default i.p.v. `.normal`.
    static func backdrop(_ path: String?, variant: TMDBImageVariant = .hero) -> URL? {
        url(path: path, kind: .backdrop, variant: variant)
    }

    /// Acteur-/persoonsportret (altijd klein genoeg, geen `original` nodig).
    static func profile(_ path: String?) -> URL? {
        url(path: path, kind: .profile, variant: .normal)
    }

    /// Clearlogo/streamingdienst-logo. Streamingdienst-badges zijn klein (`.small`); het grote
    /// titel-clearlogo op de Stage gebruikt `.large`.
    static func logo(_ path: String?, variant: TMDBImageVariant = .large) -> URL? {
        url(path: path, kind: .logo, variant: variant)
    }
}
