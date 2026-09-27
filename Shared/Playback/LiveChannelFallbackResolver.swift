import Foundation

/// Zoekt, wanneer een live-zender niet start, automatisch dezelfde zender op
/// bij een van je ANDERE ingestelde IPTV-playlists -- zodat je niet zelf naar
/// "Zender wijzigen" hoeft als één provider hapert. Matcht op genormaliseerde
/// zendernaam (kwaliteitssuffixen als "HD"/"FHD"/"4K" genegeerd), zodat
/// "Kanaal 1 FHD" bij de ene playlist "Kanaal 1 HD" bij een andere nog steeds
/// als dezelfde zender herkend wordt.
///
/// `PlaybackViewModel` roept dit precies één keer aan zodra een live-bron een
/// afspeelfout geeft, en speelt de gevonden bron automatisch verder -- vindt
/// dit niets, dan blijft de gewone foutmelding (met "Opnieuw proberen") staan.
enum LiveChannelFallbackResolver {
    static func resolve(after failed: PlayableSource) async -> PlayableSource? {
        guard failed.kind == .liveTV else { return nil }

        let target = normalized(failed.name)
        guard !target.isEmpty else { return nil }

        guard let providers = try? IPTVConfigurationStore().loadProviders() else { return nil }
        let service = IPTVService()
        let preferencesStore = IPTVProviderPreferencesStore()

        // Eerst het reserveadres van DEZELFDE playlist proberen (zelfde
        // stream-URL, enkel host/poort geruild) -- pas daarna andere
        // ingestelde playlists doorzoeken.
        if let sameProvider = providers.first(where: { $0.displayName == failed.providerName }),
           case .xtream(let sameConfig) = sameProvider.configuration,
           let backupServerURL = sameConfig.backupServerURL,
           let backupStreamURL = Self.swappingHost(of: failed.url, with: backupServerURL) {
            return PlayableSource(
                name: failed.name,
                description: failed.description,
                url: backupStreamURL,
                kind: .liveTV,
                providerName: failed.providerName,
                epgChannelID: failed.epgChannelID,
                epgProgrammes: failed.epgProgrammes
            )
        }

        // Andere playlists dan die van de gefaalde bron proberen, in de
        // volgorde waarin ze ingesteld staan. Eén match volstaat.
        for provider in providers where provider.displayName != failed.providerName {
            guard case .xtream(let xtreamConfig) = provider.configuration else { continue }
            guard !Task.isCancelled else { return nil }

            let preferences = preferencesStore.load(for: provider.configuration)

            guard let categories = try? await service.loadXtreamLiveCategories(configuration: xtreamConfig)
            else { continue }

            for category in categories where preferences.isLiveCategoryVisible(category.id) {
                guard !Task.isCancelled else { return nil }
                guard let channels = try? await service.loadXtreamLiveChannels(
                    configuration: xtreamConfig, categoryID: category.id
                ) else { continue }

                if let match = channels.first(where: {
                    preferences.isLiveChannelVisible($0.id) && normalized($0.name) == target
                }) {
                    return PlayableSource(
                        name: "\(failed.name) · \(provider.displayName)",
                        description: category.name,
                        url: match.streamURL,
                        kind: .liveTV,
                        providerName: provider.displayName,
                        epgChannelID: match.tvgID
                    )
                }
            }
        }

        return nil
    }

    /// Herbouwt een stream-URL met host/poort/schema van `backupServerURL`,
    /// met behoud van pad en query (Xtream-stream-URL's zijn
    /// `schema://host:poort/live/gebruiker/wachtwoord/id.ext` -- enkel het
    /// serveradres verschilt tussen hoofd- en reserveadres van hetzelfde
    /// account).
    private static func swappingHost(of url: URL, with backupServerURL: URL) -> URL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let backupComponents = URLComponents(url: backupServerURL, resolvingAgainstBaseURL: false)
        else { return nil }

        components.scheme = backupComponents.scheme
        components.host = backupComponents.host
        components.port = backupComponents.port
        return components.url
    }

    private static func normalized(_ value: String) -> String {
        var result = value.folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        ).lowercased()

        // Veelvoorkomende kwaliteits-/resolutiesuffixen negeren, zodat
        // "Kanaal 1 FHD" en "Kanaal 1 HD" als dezelfde zender matchen.
        for suffix in ["4k", "uhd", "fhd", "hd", "sd", "hevc"] {
            result = result.replacingOccurrences(of: "\\b\(suffix)\\b", with: "", options: .regularExpression)
        }

        result = result.replacingOccurrences(of: "[^a-z0-9]+", with: "", options: .regularExpression)
        return result
    }
}
