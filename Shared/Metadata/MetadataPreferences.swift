import Foundation

enum MetadataRatingProvider:
    String,
    CaseIterable,
    Identifiable
{
    case imdb
    case tmdb
    case tomatometer
    case metacritic
    case trakt
    case popcornmeter

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .imdb:
            return "IMDb"

        case .tmdb:
            return "TMDB"

        case .tomatometer:
            return "Tomatometer"

        case .metacritic:
            return "Metacritic"

        case .trakt:
            return "Trakt"

        case .popcornmeter:
            return "Popcornmeter"
        }
    }

    var storageKey: String {
        "metadata.rating.\(rawValue)"
    }

    var systemImage: String {
        switch self {
        case .imdb:
            return "star.fill"

        case .tmdb:
            return "film.stack.fill"

        case .tomatometer:
            return "circle.fill"

        case .metacritic:
            return "circle.circle.fill"

        case .trakt:
            return "checkmark.square.fill"

        case .popcornmeter:
            return "popcorn.fill"
        }
    }

    /// Naam van het echte merklogo in Assets.xcassets (als "Template Image",
    /// zodat de bestaande kleur-badge er nog steeds achter kan zitten). `nil`
    /// betekent: geen eigen logo beschikbaar, val terug op `systemImage`.
    /// Popcornmeter heeft geen apart merk (het is Rotten Tomatoes' publieksscore),
    /// dus die houdt het SF Symbool.
    var assetImageName: String? {
        switch self {
        case .imdb:
            return "rating-imdb"

        case .tmdb:
            return "rating-tmdb"

        case .tomatometer:
            return "rating-rottentomatoes"

        case .metacritic:
            return "rating-metacritic"

        case .trakt:
            return "rating-trakt"

        case .popcornmeter:
            return nil
        }
    }
}

enum MetadataPreferences {
    static func isEnabled(
        _ provider: MetadataRatingProvider
    ) -> Bool {
        let defaults =
            UserDefaults.standard

        guard
            defaults.object(
                forKey:
                    provider.storageKey
            ) != nil
        else {
            return true
        }

        return defaults.bool(
            forKey:
                provider.storageKey
        )
    }

    static func setEnabled(
        _ enabled: Bool,
        for provider: MetadataRatingProvider
    ) {
        UserDefaults.standard.set(
            enabled,
            forKey:
                provider.storageKey
        )
    }

    static var showIMDb: Bool {
        isEnabled(.imdb)
    }

    static var showTMDB: Bool {
        isEnabled(.tmdb)
    }

    static var showTomatometer: Bool {
        isEnabled(.tomatometer)
    }

    static var showMetacritic: Bool {
        isEnabled(.metacritic)
    }

    static var showTrakt: Bool {
        isEnabled(.trakt)
    }

    static var showPopcornmeter: Bool {
        isEnabled(.popcornmeter)
    }
}
