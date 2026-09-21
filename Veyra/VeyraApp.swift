import SwiftUI
import UIKit

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

    // Auto-refresh van IPTV VOD/EPG bij het opstarten van de app, met een
    // kleine laadanimatie die verdwijnt zodra het klaar is. Zie
    // `Shared/LiveTV/IPTVStartupRefreshCoordinator.swift`.
    @StateObject private var iptvStartupRefresh = IPTVStartupRefreshCoordinator()

    var body: some Scene {
        WindowGroup {
            ZStack {
                contentScene

                IPTVStartupRefreshBadge(coordinator: iptvStartupRefresh)
                    .padding(.top, 40)
                    .padding(.trailing, 60)

                if showLaunchAnimation {
                    LaunchAnimationView {
                        showLaunchAnimation = false
                    }
                    .transition(.identity)
                    .zIndex(1)
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
                    // Instellingen via iCloud spiegelen — zie
                    // `Shared/Sync/CloudSettingsSync.swift`.
                    CloudSettingsSync.shared.start()

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

                    // IPTV VOD en EPG (zenderlijst) rechtstreeks
                    // verversen bij opstarten, voor elke
                    // geconfigureerde provider tegelijk. De kleine
                    // badge (zie `iptvStartupRefresh`) blijft
                    // zichtbaar zolang dit loopt.
                    await iptvStartupRefresh.beginRefresh {
                        await refreshAllIPTVDataOnStartup()
                    }
                }
                .onChange(
                    of:
                        scenePhase
                ) { _, phase in
                    guard
                        phase
                            == .active
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

    // MARK: - IPTV startup refresh

    /// Ververst voor elke geconfigureerde IPTV-provider de zenderlijst
    /// ("EPG") en de VOD-catalogus tegelijk. Fouten bij één provider
    /// blokkeren de andere providers niet — de app heeft hier verder geen
    /// foutmelding voor nodig, de betrokken schermen tonen zelf een
    /// foutstatus zodra de gebruiker ernaartoe navigeert.
    private func refreshAllIPTVDataOnStartup() async {
        guard
            let providers = try? IPTVConfigurationStore().loadProviders(),
            !providers.isEmpty
        else {
            return
        }

        await withTaskGroup(of: Void.self) { group in
            for provider in providers {
                group.addTask {
                    await refreshIPTVProviderOnStartup(provider.configuration)
                }
            }
        }
    }

    private func refreshIPTVProviderOnStartup(_ configuration: IPTVStoredConfiguration) async {
        let service = IPTVService()

        switch configuration {
        case .xtream(let xtream):
            async let liveChannels: [IPTVChannel]? = try? service.loadXtreamLiveChannels(configuration: xtream)
            async let vodItems: [IPTVVODItem]? = try? service.loadXtreamVOD(configuration: xtream)
            _ = await (liveChannels, vodItems)

        case .m3u(let m3u):
            _ = try? await service.loadM3UChannels(configuration: m3u)
        }
    }
}
