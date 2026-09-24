import SwiftUI

/// Algemene Veyra-voorkeuren: startscherm, sportweergave, kaartweergave en
/// toegankelijkheid. Zie `GeneralSettings.swift` (Shared) voor per
/// instelling wat al echt werkt en wat nog een stub is.
struct GeneralSettingsView: View {
    // Startscherm
    @AppStorage(GeneralSettingsDefaults.showContinueWatchingKey)
    private var showContinueWatching = true
    @AppStorage(GeneralSettingsDefaults.continueWatchingLimitKey)
    private var continueWatchingLimit = 10
    @AppStorage(GeneralSettingsDefaults.hideContinueWatchingReleaseDateKey)
    private var hideContinueWatchingReleaseDate = false
    @AppStorage(GeneralSettingsDefaults.showUpcomingKey)
    private var showUpcoming = true
    @AppStorage(GeneralSettingsDefaults.includeWatchlistPremieresKey)
    private var includeWatchlistPremieres = true

    // Sport
    @AppStorage(GeneralSettingsDefaults.hideScoreSpoilersKey)
    private var hideScoreSpoilers = false
    @AppStorage(GeneralSettingsDefaults.chooseChannelOnTapKey)
    private var chooseChannelOnTap = false

    // Kaarten & posters
    @AppStorage(GeneralSettingsDefaults.showReleaseYearKey)
    private var showReleaseYear = true
    @AppStorage(GeneralSettingsDefaults.hideTitlesUnderPostersKey)
    private var hideTitlesUnderPosters = false
    @AppStorage(GeneralSettingsDefaults.hideEpisodesRemainingKey)
    private var hideEpisodesRemaining = false

    // Toegankelijkheid
    @AppStorage(GeneralSettingsDefaults.textSizeKey)
    private var textSizeRaw = GeneralTextSize.defaultSize.rawValue

    // iPad-navigatie
    @AppStorage(GeneralSettingsDefaults.ipadNavigationStyleKey)
    private var ipadNavigationStyleRaw = IPadNavigationStyle.sidebar.rawValue

    var body: some View {
        ZStack {
            VeyraColors.background.ignoresSafeArea()

            List {
                Section {
                    Toggle("Verder kijken tonen", isOn: $showContinueWatching)

                    Stepper(
                        "Aantal tegels: \(continueWatchingLimit)",
                        value: $continueWatchingLimit,
                        in: 1...30
                    )
                    .disabled(!showContinueWatching)

                    Toggle("Releasedatum verbergen op verder-kijken-kaarten", isOn: $hideContinueWatchingReleaseDate)
                        .disabled(!showContinueWatching)

                    Toggle("Binnenkort tonen", isOn: $showUpcoming)

                    Toggle("Premières uit kijklijst meenemen", isOn: $includeWatchlistPremieres)
                        .disabled(!showUpcoming)
                } header: {
                    sectionHeader("Startscherm", symbol: "rectangle.stack", tint: VeyraColors.cyan)
                } footer: {
                    Text("Verder kijken toont titels die je begonnen bent; Aantal tegels begrenst hoeveel er verschijnen (meest recente behouden). Binnenkort toont de volgende aflevering — en de uitzenddatum — voor series waar je bij bent. \"Releasedatum verbergen\" heeft nog geen effect: verder-kijken-kaarten tonen momenteel geen datum om te verbergen. \"Premières uit kijklijst\" is nog niet aangesloten — dat vraagt releasedata per kijklijst-item die Veyra nu nog niet opzoekt.")
                }

                Section {
                    Toggle("Uitslag verbergen tot tik", isOn: $hideScoreSpoilers)
                    Toggle("Zender kiezen bij tik", isOn: $chooseChannelOnTap)
                } header: {
                    sectionHeader("Sport", symbol: "sportscourt", tint: VeyraColors.red)
                } footer: {
                    Text("\"Uitslag verbergen tot tik\" vervaagt de stand op live en afgelopen wedstrijden tot je erop tikt — actief op Home en de wedstrijdpagina. \"Zender kiezen bij tik\" heeft nog geen effect: Veyra heeft nog geen zender-/uitzendingskeuze bij sportwedstrijden.")
                }

                Section {
                    Toggle("Releasejaar tonen", isOn: $showReleaseYear)
                    Toggle("Titel onder poster verbergen", isOn: $hideTitlesUnderPosters)
                    Toggle("Resterende afleveringen verbergen", isOn: $hideEpisodesRemaining)
                } header: {
                    sectionHeader("Kaarten & posters", symbol: "photo.on.rectangle.angled", tint: VeyraColors.ice)
                } footer: {
                    Text("Releasejaar en titel-onder-poster zijn actief op Home, Films en Series. \"Resterende afleveringen verbergen\" heeft nog geen effect: Veyra toont nergens een \"X resterend\"-telling om te verbergen.")
                }

                Section {
                    Picker("Tekstgrootte", selection: $textSizeRaw) {
                        ForEach(GeneralTextSize.allCases) { size in
                            Text(size.title).tag(size.rawValue)
                        }
                    }
                } header: {
                    sectionHeader("Toegankelijkheid", symbol: "textformat.size", tint: VeyraColors.secondary)
                } footer: {
                    Text("Past tekst aan die Dynamic Type volgt. De meeste titels en koppen in Veyra gebruiken een vaste grootte en reageren hier nog niet op.")
                }

                Section {
                    Picker("Navigatie", selection: $ipadNavigationStyleRaw) {
                        ForEach(IPadNavigationStyle.allCases) { style in
                            Text(style.title).tag(style.rawValue)
                        }
                    }
                } header: {
                    sectionHeader("iPad-navigatie", symbol: "sidebar.left", tint: VeyraColors.cyan)
                } footer: {
                    Text("Kies of Veyra op de iPad een zijbalk of een menubalk bovenaan gebruikt — nooit allebei tegelijk. Op iPhone heeft dit geen effect (altijd een tabbalk onderaan).")
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Algemeen")
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
    NavigationStack { GeneralSettingsView() }
}
