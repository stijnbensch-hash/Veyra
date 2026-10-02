import SwiftUI

// Zelfde patroon als `.iptvConfigurationDidChange` (zie `IPTVAccountsView.swift`):
// per platform een eigen extensie i.p.v. gedeeld, want de tvOS-versie zit in
// `Veyra/VeyraApp.swift`, dat niet in dit target zit.
extension Notification.Name {
    static let iptvHomeRefreshRequested =
        Notification.Name("veyra.iptv.home.refreshRequested")
}

@main
struct VeyraMacApp: App {
    @StateObject private var iptvStartupRefresh = IPTVStartupRefreshCoordinator()
    @StateObject private var iptvStartupGuide = VeyraEPGStore()

    @AppStorage(DataSettingsDefaults.autoRefreshOnForegroundKey)
    private var autoRefreshOnForeground = true

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MacContentView()
                .preferredColorScheme(.dark)
                .task {
                    VeyraHubSyncService.shared.start()

                    // Fase 2 ("Regional Releases"): registreer de (tijdelijke) mock-provider,
                    // zie `Veyra/VeyraApp.swift` voor de volledige toelichting.
                    await RegionalReleaseProviderRegistry.shared.register(VRTRegionalReleaseProvider())
                    await RegionalReleaseProviderRegistry.shared.register(IPTVVODRegionalReleaseProvider())
                    VeyraHubWatchStateSyncService.shared.start()
                    VeyraTraktWatchStateReconciler.shared.start()

                    await iptvStartupRefresh.beginRefresh {
                        await iptvStartupGuide.reload()
                        await IPTVDiskCache.flush()
                        NotificationCenter.default.post(name: .iptvConfigurationDidChange, object: nil)
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active, autoRefreshOnForeground else { return }
                    Task {
                        await TraktStore.shared.refreshIfNeeded()
                        NotificationCenter.default.post(name: .iptvHomeRefreshRequested, object: nil)
                    }
                }
                .frame(minWidth: 1000, minHeight: 650)
        }
        .windowStyle(.titleBar)
    }
}
