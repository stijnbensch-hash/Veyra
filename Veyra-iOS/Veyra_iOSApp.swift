//
//  Veyra_iOSApp.swift
//  Veyra-iOS
//
//  Created by Stijn Bensch on 19/09/2026.
//

import SwiftUI

@main
struct Veyra_iOSApp: App {
    // Nodig zodat `OrientationLock` (Playback/OrientationLock.swift) de
    // toegestane schermoriëntaties tijdens het afspelen kan beperken —
    // zie "Automatisch draaien naar liggend" in de Afspelen-instellingen.
    @UIApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

    @AppStorage(GeneralSettingsDefaults.textSizeKey)
    private var textSizeRaw = GeneralTextSize.defaultSize.rawValue

    // Toont de openingsanimatie (beeldmerk verschijnt, vliegt dan weg) één
    // keer bij een koude start. `showLaunchAnimation` blijft in dit
    // App-struct staan zolang het proces leeft, dus komt niet terug bij
    // achtergrond/voorgrond-wissels. Zie `Shared/LaunchAnimationView.swift`.
    @State private var showLaunchAnimation = true

    // Auto-refresh van IPTV VOD/EPG bij het opstarten van de app, met een
    // kleine laadanimatie die verdwijnt zodra het klaar is. Zie
    // `Shared/LiveTV/IPTVStartupRefreshCoordinator.swift`.
    @StateObject private var iptvStartupRefresh = IPTVStartupRefreshCoordinator()

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    // "Tekstgrootte" (Algemeen-instellingen). Werkt op tekst die
                    // Dynamic Type volgt; de meeste vaste `.system(size:)`-
                    // koppen/titels in Veyra reageren hier niet op — zie
                    // `GeneralSettings.swift`.
                    .environment(\.dynamicTypeSize, (GeneralTextSize(rawValue: textSizeRaw) ?? .defaultSize).dynamicTypeSize)
                    .task {
                        // Instellingen/planken/hero/addons spiegelen tussen
                        // apparaten via de gekoppelde VeyraHub-server — zie
                        // `Shared/Sync/VeyraHubSyncService.swift`.
                        VeyraHubSyncService.shared.start()

                        // Bestaande schermen (LiveTVView, IPTVRecentlyAddedRows)
                        // verversen zichzelf al zodra ze de
                        // `.iptvConfigurationDidChange`-notificatie ontvangen —
                        // dus bij opstarten alleen het startsein geven, net als
                        // tvOS (`VeyraApp.iptvHomeRefreshRequested`).
                        await iptvStartupRefresh.beginRefresh {
                            NotificationCenter.default.post(name: .iptvConfigurationDidChange, object: nil)
                        }
                    }

                IPTVStartupRefreshBadge(coordinator: iptvStartupRefresh)
                    .padding(.top, 8)
                    .padding(.trailing, 16)

                if showLaunchAnimation {
                    LaunchAnimationView {
                        showLaunchAnimation = false
                    }
                    .transition(.identity)
                    .zIndex(1)
                }
            }
            .statusBarHidden(showLaunchAnimation)
            .persistentSystemOverlays(showLaunchAnimation ? .hidden : .automatic)
        }
    }
}
