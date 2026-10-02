// VeyraCollectionArtworkResolver.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// Eén centrale artwork-identiteit per collectie (spec §7): browser, Home, "Verder met je
// collecties" en Collection Detail roepen allemaal DEZE functie aan i.p.v. elk apart een backdrop
// te kiezen. Fallback-keten (spec §8, vereenvoudigd tot wat Veyra daadwerkelijk heeft -- geen
// collage-stap, spec §64 is bewust lager-prioriteit):
//
//   1. eigen afbeelding / expliciet gekozen fanart (`collection.artworkReference`)
//   2. backdrop van het meest prominente film in de collectie (door de aanroeper meegegeven,
//      want dat vereist al opgeloste metadata die deze resolver zelf niet opnieuw ophaalt)
//   3. `nil` -> aanroeper valt terug op de Veyra-placeholder (dark/cyaan gradient)
//
// `VeyraHub`: een lokaal bestandspad (`VeyraCollectionArtworkStore`) is NIET bruikbaar op een
// ander apparaat na sync -- zelfde beperking als de bestaande Home-banners
// (`VeyraCollectionsStore.imageURL`), bewust niet opgelost hier (spec §76: "bouw daadwerkelijke
// binary asset sync nog niet tenzij bestaande VeyraHub code dit al ondersteunt" -- die
// ondersteuning is er nog niet).

import Foundation

enum VeyraCollectionArtworkResolver {
    static func resolvedURL(for collection: VeyraCollection, fallback: URL? = nil) -> URL? {
        if let custom = collection.artworkReference, !custom.isEmpty {
            if custom.hasPrefix("http"), let url = URL(string: custom) { return url }
            let local = VeyraCollectionArtworkStore.imagesDirectory.appendingPathComponent(custom)
            if FileManager.default.fileExists(atPath: local.path) { return URL(fileURLWithPath: local.path) }
        }
        return fallback
    }
}

/// Zelfde opzet als `VeyraCollectionArtworkResolver`, maar voor het clearlogo -- enkel de
/// EXPLICIET gekozen `clearLogoReference` (sync, geen netwerk). De automatische TMDB-clearlogo
/// van het meest prominente deel blijft bewust beperkt tot de Stage (`VeyraClearLogo` in
/// `VeyraCollectionDetailView`), nooit per kaart in een raster -- anders komt de "te veel
/// gelijktijdige TMDB-aanvragen"-traagheid terug die de gedeelde `TMDBMetadataCache` net oploste.
enum VeyraCollectionClearLogoResolver {
    static func resolvedURL(for collection: VeyraCollection) -> URL? {
        guard let custom = collection.clearLogoReference, !custom.isEmpty else { return nil }
        if custom.hasPrefix("http") { return URL(string: custom) }
        let local = VeyraCollectionArtworkStore.imagesDirectory.appendingPathComponent(custom)
        if FileManager.default.fileExists(atPath: local.path) { return URL(fileURLWithPath: local.path) }
        return nil
    }
}
