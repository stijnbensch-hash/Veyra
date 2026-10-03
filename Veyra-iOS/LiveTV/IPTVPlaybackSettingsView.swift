import SwiftUI

/// Live TV-voorkeuren: gidsvormgeving, afspeelmotor, buffering/catch-up en
/// hoe vaak zenderlijst/gids ververst worden. De cache-intervallen en
/// wisknoppen zijn aangesloten op VeyraEPGStore.
struct IPTVPlaybackSettingsView: View {
    @AppStorage(IPTVPlaybackSettingsDefaults.guideThemeKey)
    private var guideThemeRaw = IPTVGuideTheme.colourful.rawValue
    @AppStorage(IPTVPlaybackSettingsDefaults.hideCountryPrefixKey)
    private var hideCountryPrefix = true

    @AppStorage(IPTVPlaybackSettingsDefaults.playerEngineKey)
    private var playerEngineRaw = IPTVPlayerEngineOption.intern.rawValue

    @AppStorage(IPTVPlaybackSettingsDefaults.bufferDurationKey)
    private var bufferDurationRaw = IPTVBufferDurationOption.none.rawValue
    @AppStorage(IPTVPlaybackSettingsDefaults.catchUpOffsetModeKey)
    private var catchUpOffsetModeRaw = IPTVCatchUpOffsetMode.automatic.rawValue
    @AppStorage(IPTVPlaybackSettingsDefaults.catchUpOffsetManualSecondsKey)
    private var catchUpOffsetManualSeconds = 0

    @AppStorage(IPTVPlaybackSettingsDefaults.showFPSCounterKey)
    private var showFPSCounter = false

    private var catchUpOffsetMode: IPTVCatchUpOffsetMode {
        IPTVCatchUpOffsetMode(rawValue: catchUpOffsetModeRaw) ?? .automatic
    }

    var body: some View {
        VeyraDynamicBackgroundScope {
            ZStack {
                VeyraBackground().ignoresSafeArea()

                VeyraList {
                    Section {
                        Picker("Gidsthema", selection: $guideThemeRaw) {
                            ForEach(IPTVGuideTheme.allCases) { theme in
                                Text(theme.title).tag(theme.rawValue)
                            }
                        }
                        Toggle("Landcode voor zendernaam verbergen", isOn: $hideCountryPrefix)
                    } header: {
                        sectionHeader("Zenderguide", symbol: "tv.badge.wifi", tint: VeyraColors.cyan)
                    } footer: {
                        Text("Gidsthema past de kleuren van de programmagids aan. Bij ingeschakeld wordt de landcode voor zendernamen weggelaten (bv. \"AU: Fox Sports 503\" wordt \"Fox Sports 503\").")
                    }

                    Section {
                        Picker("Afspeelmotor", selection: $playerEngineRaw) {
                            ForEach(IPTVPlayerEngineOption.allCases) { option in
                                Text(option.title).tag(option.rawValue)
                            }
                        }

                        Picker("Buffering", selection: $bufferDurationRaw) {
                            ForEach(IPTVBufferDurationOption.allCases) { option in
                                Text(option.title).tag(option.rawValue)
                            }
                        }

                        Picker("Catch-up-tijdcorrectie", selection: $catchUpOffsetModeRaw) {
                            ForEach(IPTVCatchUpOffsetMode.allCases) { mode in
                                Text(mode.title).tag(mode.rawValue)
                            }
                        }

                        if catchUpOffsetMode == .manual {
                            Stepper(
                                "Correctie: \(catchUpOffsetManualSeconds) sec",
                                value: $catchUpOffsetManualSeconds,
                                in: -3600...3600,
                                step: 60
                            )
                        }
                    } header: {
                        sectionHeader("Afspelen", symbol: "play.laptopcomputer", tint: VeyraColors.ice)
                    } footer: {
                        Text("Afspeelmotor bepaalt welke engine live-zenders afspeelt. Buffering: hoeveel live video vooraf klaarstaat. Catch-up-tijdcorrectie volgt normaal de klok van de provider; zet 'm op handmatig als terugkijken op het verkeerde moment start. Nog niet aangesloten op de speler.")
                    }

                    Section {
                        Toggle("FPS-teller tonen", isOn: $showFPSCounter)
                    } header: {
                        sectionHeader("Ontwikkelaarsopties", symbol: "ladybug", tint: VeyraColors.red)
                    } footer: {
                        Text("Er is nog geen FPS-teller in Veyra; deze schakelaar heeft voorlopig geen effect.")
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Live TV")

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
    NavigationStack { IPTVPlaybackSettingsView() }
}
