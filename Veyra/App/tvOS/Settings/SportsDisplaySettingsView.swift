import SwiftUI

/// tvOS: Instellingen → Account → Sport. Kies welke sporten, en per sport welke
/// competities, getoond worden in het Sport-menu en op de Home-sectie "Sport".
/// Zonder opgeslagen voorkeur staat alles aan (geen filtering) — zie
/// `SportsDisplayPreferences`.
struct SportsDisplaySettingsView: View {
    @State private var enabledCategories = SportsDisplayPreferences.enabledCategories()
    @State private var enabledLeagueIDs = SportsDisplayPreferences.enabledLeagueIDs()

    private func leagues(for category: SportCategory) -> [SportsLeague] {
        SportsLeague.all.filter { $0.sport == category }
    }

    var body: some View {
        ZStack {
            VeyraBackground().ignoresSafeArea()

            List {
                ForEach(SportCategory.allCases) { category in
                    let isCategoryOn = enabledCategories.contains(category)

                    Section {
                        VeyraSettingsToggleRow(
                            icon: "sportscourt",
                            title: category.displayName,
                            subtitle: "Toon deze sport op Home en in het Sport-menu",
                            isOn: Binding(
                                get: { isCategoryOn },
                                set: { setCategory(category, enabled: $0) }
                            )
                        )

                        if isCategoryOn {
                            ForEach(leagues(for: category)) { league in
                                VeyraSettingsToggleRow(
                                    icon: league.symbol,
                                    title: league.name,
                                    isOn: Binding(
                                        get: { enabledLeagueIDs.contains(league.id) },
                                        set: { setLeague(league.id, enabled: $0) }
                                    )
                                )
                            }
                        }
                    } header: {
                        Text(category.displayName)
                    }
                }
            }
            .frame(maxWidth: 1000)
        }
        .navigationTitle("Sport")
    }

    private func setCategory(_ category: SportCategory, enabled: Bool) {
        SportsDisplayPreferences.setCategory(category, enabled: enabled)
        enabledCategories = SportsDisplayPreferences.enabledCategories()
        enabledLeagueIDs = SportsDisplayPreferences.enabledLeagueIDs()
    }

    private func setLeague(_ leagueID: String, enabled: Bool) {
        SportsDisplayPreferences.setLeague(leagueID, enabled: enabled)
        enabledCategories = SportsDisplayPreferences.enabledCategories()
        enabledLeagueIDs = SportsDisplayPreferences.enabledLeagueIDs()
    }
}
