import SwiftUI

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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
                .ignoresSafeArea(
                    .all
                )
                .task {
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
    }
}
