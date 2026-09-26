import SwiftUI

/// iOS: Instellingen → Account → Sport. Kies welke sporten, en per sport welke
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
            VeyraColors.background.ignoresSafeArea()

            List {
                ForEach(SportCategory.allCases) { category in
                    let isCategoryOn = enabledCategories.contains(category)

                    Section {
                        Toggle(
                            category.displayName,
                            isOn: Binding(
                                get: { isCategoryOn },
                                set: { setCategory(category, enabled: $0) }
                            )
                        )

                        if isCategoryOn {
                            ForEach(leagues(for: category)) { league in
                                Toggle(
                                    league.name,
                                    isOn: Binding(
                                        get: { enabledLeagueIDs.contains(league.id) },
                                        set: { setLeague(league.id, enabled: $0) }
                                    )
                                )
                            }
                        }
                    } header: {
                        Text(category.displayName)
                    } footer: {
                        if !isCategoryOn {
                            Text("Uitgeschakeld: verschijnt niet op Home of in het Sport-menu.")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Sport")
        .navigationBarTitleDisplayMode(.inline)
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

#Preview {
    NavigationStack { SportsDisplaySettingsView() }
}
