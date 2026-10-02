// IPTVDiscoveryVisibility.swift — gedeeld (tvOS/iOS/iPadOS/macOS)
// Eén centrale "mag dit hier getoond worden?"-laag voor IPTV-content in Home-discovery-secties
// ("Nieuw toegevoegd", "Nieuw op jouw zenders", en later Verder Kijken/Nu op TV/Live Sport voor
// hun IPTV-aandeel). Bouwt volledig op de al bestaande opslag -- GEEN nieuwe/parallelle
// visibility-store:
//   - kanaal/groep/VOD-categorie/VOD-item-zichtbaarheid  -> `IPTVProviderPreferences` (bestond al,
//     wordt vandaag al gebruikt door Live TV/EPG-browsing, zie `VeyraEPGStore`)
//   - provider aan/uit                                   -> `IPTVProviderEnablement` (nieuw, klein)
//
// Live TV/VOD-browsing-schermen filteren vandaag al rechtstreeks op `IPTVProviderPreferences` voor
// de ene "actieve" provider. Deze laag is er specifiek voor discovery over MEERDERE providers
// tegelijk (waar Home doorheen moet), zodat daar niet los, per sectie, opnieuw dezelfde
// zichtbaarheidsregels herschreven worden.
//
// Nog GEEN UI hiervoor, en nog GEEN enkele Home-sectie gebruikt dit -- dat komt in latere stappen
// (zie het Home Visual System-specdocument, IPTV-stappenplan).

import Foundation

nonisolated struct IPTVDiscoveryVisibility {
    static let shared = IPTVDiscoveryVisibility()

    private let configurationStore: IPTVConfigurationStore
    private let preferencesStore: IPTVProviderPreferencesStore

    init(configurationStore: IPTVConfigurationStore = IPTVConfigurationStore(),
         preferencesStore: IPTVProviderPreferencesStore = IPTVProviderPreferencesStore()) {
        self.configurationStore = configurationStore
        self.preferencesStore = preferencesStore
    }

    /// Alle opgeslagen providers die ook ingeschakeld zijn -- het startpunt voor elke
    /// discovery-doorloop over meerdere providers tegelijk. Lege lijst bij een Keychain-leesfout
    /// (bv. nog geen providers ingesteld) i.p.v. de fout laten doorgooien: discovery moet gewoon
    /// niets tonen, niet crashen.
    func enabledProviders() -> [IPTVStoredProvider] {
        ((try? configurationStore.loadProviders()) ?? []).filter { isProviderEnabled($0.id) }
    }

    func isProviderEnabled(_ providerID: UUID) -> Bool {
        IPTVProviderEnablement.isEnabled(providerID)
    }

    func isChannelVisible(_ channelID: String, provider: IPTVStoredProvider) -> Bool {
        guard isProviderEnabled(provider.id) else { return false }
        return preferences(for: provider).isLiveChannelVisible(channelID)
    }

    func isChannelGroupVisible(_ groupID: String, provider: IPTVStoredProvider) -> Bool {
        guard isProviderEnabled(provider.id) else { return false }
        return preferences(for: provider).isLiveCategoryVisible(groupID)
    }

    func isVODCategoryVisible(_ categoryID: String, provider: IPTVStoredProvider) -> Bool {
        guard isProviderEnabled(provider.id) else { return false }
        return preferences(for: provider).isVODCategoryVisible(categoryID)
    }

    /// `categoryID` optioneel meegeven wanneer bekend -- een verborgen categorie verbergt ook al
    /// haar items, ook als het item zelf nooit los verborgen werd.
    func isVODItemVisible(_ itemID: String, categoryID: String?, provider: IPTVStoredProvider) -> Bool {
        guard isProviderEnabled(provider.id) else { return false }
        let prefs = preferences(for: provider)
        if let categoryID, !prefs.isVODCategoryVisible(categoryID) { return false }
        return prefs.isVODItemVisible(itemID)
    }

    func isSeriesCategoryVisible(_ categoryID: String, provider: IPTVStoredProvider) -> Bool {
        guard isProviderEnabled(provider.id) else { return false }
        return preferences(for: provider).isSeriesCategoryVisible(categoryID)
    }

    func isSeriesItemVisible(_ itemID: String, categoryID: String?, provider: IPTVStoredProvider) -> Bool {
        guard isProviderEnabled(provider.id) else { return false }
        let prefs = preferences(for: provider)
        if let categoryID, !prefs.isSeriesCategoryVisible(categoryID) { return false }
        return prefs.isSeriesItemVisible(itemID)
    }

    private func preferences(for provider: IPTVStoredProvider) -> IPTVProviderPreferences {
        preferencesStore.load(for: provider.configuration)
    }
}
