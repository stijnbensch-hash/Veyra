import SwiftUI

/// tvOS: Instellingen → Data. Cache legen, automatisch verversen bij het
/// terugkeren naar de app, zenderlijst-/gidsverversing en VeyraHub Recorder
/// -- verzameld op één plek i.p.v. verspreid over Algemeen en Live TV.
struct DataSettingsView: View {
    @AppStorage(DataSettingsDefaults.autoRefreshOnForegroundKey)
    private var autoRefreshOnForeground = true

    @AppStorage(RecorderSettingsDefaults.autoDeleteAfterWatchedKey)
    private var autoDeleteAfterWatched = false

    @AppStorage(IPTVPlaybackSettingsDefaults.refreshChannelsIntervalKey)
    private var refreshChannelsIntervalRaw = IPTVCacheRefreshInterval.sixHours.rawValue
    @AppStorage(IPTVPlaybackSettingsDefaults.refreshEPGIntervalKey)
    private var refreshEPGIntervalRaw = IPTVCacheRefreshInterval.twelveHours.rawValue

    @State private var cacheAlertMessage: String?

    var body: some View {
        ZStack {
            VeyraBackground().ignoresSafeArea()

            List {
                Section {
                    Button {
                        AppCacheManager.clearAll()
                        cacheAlertMessage = "Cache gewist. Afbeeldingen, zenderlijst en gids worden opnieuw geladen."
                    } label: {
                        VeyraSettingsCardRowLabel(icon: "trash", title: "Cache legen")
                    }
                    .veyraCardRow()
                } header: {
                    Text("Cache")
                } footer: {
                    Text("Wist afbeeldingen-/API-cache en de lokale zenderlijst- en gidscache. Niets van je account (Trakt, kijklijst, voortgang) gaat verloren.")
                }

                Section {
                    VeyraSettingsToggleRow(icon: "arrow.triangle.2.circlepath", title: "Automatisch alles opnieuw laden",
                                           subtitle: "Ververst Trakt en Live TV zodra je Veyra weer opent",
                                           isOn: $autoRefreshOnForeground)
                } header: {
                    Text("Verversen")
                }

                Section {
                    VeyraSettingsChoiceRow<IPTVCacheRefreshInterval>(icon: "list.bullet.rectangle", "Zenderlijst verversen", selection: $refreshChannelsIntervalRaw)
                    VeyraSettingsChoiceRow<IPTVCacheRefreshInterval>(icon: "calendar", "Programmagids verversen", selection: $refreshEPGIntervalRaw)
                } header: {
                    Text("Live TV")
                }

                Section {
                    VeyraSettingsToggleRow(icon: "record.circle", title: "Verwijder automatisch na kijken",
                                           subtitle: "Verwijdert een VeyraHub-opname zodra je hem hebt uitgekeken",
                                           isOn: $autoDeleteAfterWatched)
                } header: {
                    Text("VeyraHub Recorder")
                }
            }
            .frame(maxWidth: 1000)
        }
        .navigationTitle("Data")
        .alert(
            "Cache",
            isPresented: Binding(
                get: { cacheAlertMessage != nil },
                set: { if !$0 { cacheAlertMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { cacheAlertMessage = nil }
        } message: {
            Text(cacheAlertMessage ?? "")
        }
    }
}
