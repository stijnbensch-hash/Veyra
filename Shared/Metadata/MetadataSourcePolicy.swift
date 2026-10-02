import Foundation

/// Centrale metadata-bronkeuze (spec "METADATA + AIOMETADATA + ARTWORK
/// ENGINE" Fase 1, §14/§18/§19/§20): leest de opgeslagen gebruikersvoorkeur
/// (`MetadataSourcePreference`) en bepaalt daaruit welke bron nu geraadpleegd
/// moet worden. Wijzigt die voorkeur zelf nooit (§20) — bij een AIOMetadata-
/// fout valt de aanroeper terug op TMDB zonder de instelling aan te passen.
enum MetadataSourcePolicy {
    enum Source: Equatable {
        case tmdb
        case aioMetadata(AddonManifest)

        static func == (lhs: Source, rhs: Source) -> Bool {
            switch (lhs, rhs) {
            case (.tmdb, .tmdb):
                return true
            case (.aioMetadata(let lAddon), .aioMetadata(let rAddon)):
                return lAddon.id == rAddon.id
            default:
                return false
            }
        }
    }

    /// De bron die nu geraadpleegd moet worden. `.tmdb` als de voorkeur op
    /// AIOMetadata staat maar er (nog) geen bruikbare addon geconfigureerd
    /// is bij Addons — zelfde gedrag als de bestaande
    /// `MetadataSourcePreference.activeAddon()`.
    static func activeSource() -> Source {
        if let addon = MetadataSourcePreference.activeAddon() {
            return .aioMetadata(addon)
        }
        return .tmdb
    }
}
