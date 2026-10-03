import SwiftUI

/// Instellingen → Data (iOS/iPad/Mac). Cache legen, automatisch verversen
/// bij het terugkeren naar de app, zenderlijst-/gidsverversing en VeyraHub
/// Recorder — verzameld op één plek i.p.v. verspreid over Algemeen en Live TV.
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
        VeyraDynamicBackgroundScope {
            ZStack {
                VeyraBackground().ignoresSafeArea()

                VeyraList {
                    Section {
                        Button("Cache legen", role: .destructive) {
                            AppCacheManager.clearAll()
                            cacheAlertMessage = "Cache gewist. Afbeeldingen, zenderlijst en gids worden opnieuw geladen."
                        }
                    } header: {
                        sectionHeader("Cache", symbol: "trash", tint: VeyraColors.secondary)
                    } footer: {
                        Text("Wist afbeeldingen-/API-cache en de lokale zenderlijst- en gidscache. Niets van je account (Trakt, kijklijst, voortgang) gaat verloren.")
                    }

                    Section {
                        Toggle("Automatisch alles opnieuw laden", isOn: $autoRefreshOnForeground)
                    } header: {
                        sectionHeader("Verversen", symbol: "arrow.triangle.2.circlepath", tint: VeyraColors.cyan)
                    } footer: {
                        Text("Ververst Trakt en Live TV zodra je Veyra weer opent.")
                    }

                    Section {
                        Picker("Zenderlijst verversen", selection: $refreshChannelsIntervalRaw) {
                            ForEach(IPTVCacheRefreshInterval.allCases) { interval in
                                Text(interval.title).tag(interval.rawValue)
                            }
                        }
                        Picker("Programmagids verversen", selection: $refreshEPGIntervalRaw) {
                            ForEach(IPTVCacheRefreshInterval.allCases) { interval in
                                Text(interval.title).tag(interval.rawValue)
                            }
                        }
                    } header: {
                        sectionHeader("Live TV", symbol: "tv", tint: VeyraColors.cyan)
                    } footer: {
                        Text("Zenders en gids worden lokaal bewaard en bij het opstarten geladen. Na het gekozen interval wordt de bron ververst.")
                    }

                    Section {
                        Toggle("Verwijder automatisch na kijken", isOn: $autoDeleteAfterWatched)
                    } header: {
                        sectionHeader("VeyraHub Recorder", symbol: "record.circle", tint: VeyraColors.red)
                    } footer: {
                        Text("Verwijdert een opname van VeyraHub zodra je hem in Veyra helemaal (of bijna) hebt uitgekeken. Geldt alleen voor opnames die je via Veyra zelf afspeelt.")
                    }
                }
                .scrollContentBackground(.hidden)
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

    @ViewBuilder
    private func sectionHeader(_ title: String, symbol: String, tint: Color) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(tint)
        }
    }
}

#Preview {
    NavigationStack { DataSettingsView() }
}
