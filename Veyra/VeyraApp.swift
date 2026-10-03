import SwiftUI
import UIKit
import TVServices

extension Notification.Name {
    static let iptvHomeRefreshRequested =
        Notification.Name(
            "veyra.iptv.home.refreshRequested"
        )
}

@main
struct VeyraApp: App {
    @Environment(\.scenePhase)
    private var scenePhase

    @AppStorage(DataSettingsDefaults.autoRefreshOnForegroundKey)
    private var autoRefreshOnForeground = true

    // tvOS kent `.scrollContentBackground(.hidden)` niet (die modifier
    // bestaat wel op iOS, maar is niet beschikbaar op tvOS), waardoor de
    // standaard lichte achtergrond van List/Form door onze eigen donkere
    // `VeyraBackground()` heen bleef schijnen ("witte balken" in
    // Instellingen). Dit is de tvOS-tegenhanger: de achtergrond van de
    // onderliggende UITableView/UICollectionView app-breed transparant
    // maken, zodat overal (List én Form) onze eigen achtergrond zichtbaar
    // blijft.
    init() {
        UITableView.appearance().backgroundColor = .clear
        UICollectionView.appearance().backgroundColor = .clear
    }

    // Toont de openingsanimatie (beeldmerk verschijnt, vliegt dan weg) één
    // keer bij een koude start — zie `Shared/LaunchAnimationView.swift`.
    @State private var showLaunchAnimation = true

    // `contentScene` (met z'n eigen opstart-`.task`-werk) wordt pas gebouwd NADAT de
    // animatie zelf al op het scherm staat (`LaunchAnimationView`'s `onAppear` hieronder) --
    // anders delen beide dezelfde eerste render-pass, en vertraagt het construeren van
    // `contentScene` (modellen, `.task`-opstartwerk) zichtbaar ook de allereerste frame van
    // de animatie zelf, waardoor die pas met een merkbare vertraging verschijnt i.p.v.
    // onmiddellijk bij app-start.
    @State private var showContent = false

    // Auto-refresh van IPTV VOD/EPG bij het opstarten van de app, met een
    // kleine laadanimatie die verdwijnt zodra het klaar is. Zie
    // `Shared/LiveTV/IPTVStartupRefreshCoordinator.swift`.
    @StateObject private var iptvStartupRefresh = IPTVStartupRefreshCoordinator()

    var body: some Scene {
        WindowGroup {
            ZStack {
                if showContent {
                    contentScene

                    IPTVStartupRefreshBadge(coordinator: iptvStartupRefresh)
                        .padding(.top, 40)
                        .padding(.trailing, 60)
                }

                if showLaunchAnimation {
                    LaunchAnimationView {
                        showLaunchAnimation = false
                    }
                    .transition(.identity)
                    .zIndex(1)
                    .onAppear {
                        guard !showContent else { return }
                        DispatchQueue.main.async { showContent = true }
                    }
                }
            }
        }
    }

    private var contentScene: some View {
        ContentView()
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
                .ignoresSafeArea(
                    .all
                )
                .task {
                    VeyraRuntimeDiagnostics.shared.start()
                    _ = AppConfiguration.tmdbReadAccessToken
                    TVTopShelfContentProvider.topShelfContentDidChange()

                    // Instellingen spiegelen tussen apparaten via de
                    // gekoppelde VeyraHub-server — zie
                    // `Shared/Sync/VeyraHubSyncService.swift`.
                    VeyraHubSyncService.shared.start()

                    // Fase 2 ("Regional Releases"): registreer de (tijdelijke) mock-provider zodat
                    // de volledige pijplijn (adapter → registry → repository) end-to-end werkt
                    // zonder een ongeverifieerde VRT/VTM/Play/Streamz-endpoint te gokken.
                    await RegionalReleaseProviderRegistry.shared.register(VRTRegionalReleaseProvider())
                    await RegionalReleaseProviderRegistry.shared.register(IPTVVODRegionalReleaseProvider())
                    VeyraHubWatchStateSyncService.shared.start()
                    VeyraTraktWatchStateReconciler.shared.start()

                    await TraktStore
                        .shared
                        .refreshIfNeeded()

                    // Beide IPTV Home-rijen krijgen
                    // bij de eerste appstart een refresh.
                    //
                    // De views tonen eerst hun bestaande
                    // schijfcache en halen daarna de
                    // actuele providerdata opnieuw op.
                    NotificationCenter
                        .default
                        .post(
                            name:
                                .iptvHomeRefreshRequested,
                            object:
                                nil
                        )


                }
                .onChange(
                    of:
                        scenePhase
                ) { _, phase in
                    guard
                        phase
                            == .active,
                        autoRefreshOnForeground
                    else {
                        return
                    }

                    Task {
                        await TraktStore
                            .shared
                            .refreshIfNeeded()

                        // Ook na terugkeer naar de app
                        // films en series automatisch
                        // laten vernieuwen.
                        NotificationCenter
                            .default
                            .post(
                                name:
                                    .iptvHomeRefreshRequested,
                                object:
                                    nil
                            )
                    }
                }
    }

}
