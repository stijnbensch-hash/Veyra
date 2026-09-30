// IPTVProviderEnablement.swift — gedeeld (tvOS/iOS/iPadOS/macOS)
// Of een IPTV-provider meedoet in Home-discovery/aggregatie (nieuwe secties als "Nieuw
// toegevoegd"/"Nieuw op jouw zenders") i.p.v. losse browsing. Los van `activeProviderID` in
// `IPTVConfigurationStore` (welke provider je NU aan het bekijken/bladeren bent) -- je kan best
// meerdere providers tegelijk "enabled" hebben voor discovery.
//
// Bewust een losse `Set<UUID>` in UserDefaults i.p.v. de bestaande, Keychain-opgeslagen
// providerlijst (`IPTVConfigurationStore`) uit te breiden met een veld: dat zou het al werkende
// opslagformaat (en zijn payload-versionering) moeten migreren voor iets dat evengoed apart kan.
// Standaard aan (`isEnabled` default true) zodat een bestaande provider zonder deze instelling
// gewoon blijft meedoen -- geen impliciete "alles uit" na een update.

import Foundation

enum IPTVProviderEnablement {
    private static let key = "veyra.iptv.provider.disabled"

    // In-memory cache: `isEnabled` wordt aangeroepen per item tijdens het filteren van
    // een hele IPTV-catalogus (mogelijk duizenden VOD-/serie-items) -- zonder cache las en
    // parsete dat bij elk item opnieuw de hele UserDefaults-set, wat bij een grote catalogus
    // de main thread merkbaar blokkeerde (app leek dan te "hangen" bij het laden).
    private static var cachedDisabledIDs: Set<UUID>?

    private static var disabledIDs: Set<UUID> {
        get {
            if let cached = cachedDisabledIDs { return cached }
            guard let strings = UserDefaults.standard.stringArray(forKey: key) else {
                cachedDisabledIDs = []
                return []
            }
            let ids = Set(strings.compactMap(UUID.init))
            cachedDisabledIDs = ids
            return ids
        }
        set {
            cachedDisabledIDs = newValue
            UserDefaults.standard.set(newValue.map(\.uuidString), forKey: key)
        }
    }

    static func isEnabled(_ providerID: UUID) -> Bool {
        !disabledIDs.contains(providerID)
    }

    static func setEnabled(_ providerID: UUID, _ enabled: Bool) {
        var ids = disabledIDs
        if enabled { ids.remove(providerID) } else { ids.insert(providerID) }
        disabledIDs = ids
    }

    /// Opschonen wanneer een provider volledig verwijderd wordt (`IPTVConfigurationStore.removeProvider`)
    /// -- anders blijft er een dood ID in de set staan.
    static func forget(_ providerID: UUID) {
        var ids = disabledIDs
        ids.remove(providerID)
        disabledIDs = ids
    }
}
