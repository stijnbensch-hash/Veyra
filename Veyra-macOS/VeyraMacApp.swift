import SwiftUI

@main
struct VeyraMacApp: App {
    @StateObject private var iptvStartupRefresh = IPTVStartupRefreshCoordinator()
    @StateObject private var iptvStartupGuide = VeyraEPGStore()

    var body: some Scene {
        WindowGroup {
            MacContentView()
                .preferredColorScheme(.dark)
                .task {
                    VeyraHubSyncService.shared.start()
                    await iptvStartupRefresh.beginRefresh {
                        await iptvStartupGuide.reload()
                        await IPTVDiskCache.flush()
                        NotificationCenter.default.post(name: .iptvConfigurationDidChange, object: nil)
                    }
                }
                .frame(minWidth: 1000, minHeight: 650)
        }
        .windowStyle(.titleBar)
    }
}
