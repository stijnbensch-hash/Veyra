import Foundation

/// Eén centrale "Cache legen"-actie voor Instellingen → Data: wist het
/// gedeelde HTTP/afbeeldingencache (`URLCache`, gebruikt door o.a.
/// `AsyncImage` en TMDB-verzoeken) en de IPTV-zenderlijst-/gidscache op
/// schijf, en vraagt open schermen daarna om zichzelf te verversen.
@MainActor
enum AppCacheManager {
    static func clearAll() {
        URLCache.shared.removeAllCachedResponses()
        VeyraArtworkLoader.shared.clearAll()

        if let configuration = try? IPTVConfigurationStore().load() {
            let identifier = configuration.providerIdentifier
            UserDefaults.standard.removeObject(forKey: VeyraIPTVSnapshot.catalogPrefix + identifier)
            UserDefaults.standard.removeObject(forKey: VeyraIPTVSnapshot.guidePrefix + identifier)
        }

        Task {
            await VeyraRuntimeDiagnostics.clearMetadataCaches()
            await TMDBRequestCoordinator.shared.clearCache()
            await IPTVDiskCache.removeAllAsync()
            NotificationCenter.default.post(name: .iptvConfigurationDidChange, object: nil)
            NotificationCenter.default.post(name: .iptvHomeRefreshRequested, object: nil)
        }
    }
}
