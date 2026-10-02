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

nonisolated enum IPTVProviderEnablement {
    private static let key = "veyra.iptv.provider.disabled"

    // In-memory cache: `isEnabled` wordt aangeroepen per item tijdens het filteren van
    // een hele IPTV-catalogus (mogelijk duizenden VOD-/serie-items) -- zonder cache las en
    // parsete dat bij elk item opnieuw de hele UserDefaults-set, wat bij een grote catalogus
    // de main thread merkbaar blokkeerde (app leek dan te "hangen" bij het laden).
    private static var cachedDisabledIDs: Set<UUID>?
    // Zelfde bewezen bug als `IPTVProviderPreferencesStore.cache`: deze cache wordt per item
    // aangeroepen tijdens IPTV-discovery/-filtering vanuit veel gelijktijdige Tasks --
    // onbeveiligde concurrente toegang tot een `static var` is een datarace en kan de app laten
    // crashen. Lock beschermt enkel de cache zelf, niet de UserDefaults-I/O.
    private static let cacheLock = NSLock()

    // Called only while cacheLock is held, including persistence and read/modify/write.
    private static func loadDisabledIDs() -> Set<UUID> {
        if let cachedDisabledIDs { return cachedDisabledIDs }
        let ids = Set((UserDefaults.standard.stringArray(forKey: key) ?? []).compactMap(UUID.init))
        cachedDisabledIDs = ids
        return ids
    }

    static func isEnabled(_ providerID: UUID) -> Bool {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return !loadDisabledIDs().contains(providerID)
    }

    static func setEnabled(_ providerID: UUID, _ enabled: Bool) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        var ids = loadDisabledIDs()
        if enabled { ids.remove(providerID) } else { ids.insert(providerID) }
        cachedDisabledIDs = ids
        UserDefaults.standard.set(ids.map(\.uuidString), forKey: key)
    }

    static func forget(_ providerID: UUID) {
        setEnabled(providerID, true)
    }
}
