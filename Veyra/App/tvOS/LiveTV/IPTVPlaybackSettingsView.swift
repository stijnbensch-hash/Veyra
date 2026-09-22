import SwiftUI

/// tvOS-versie van de Live TV-voorkeuren: gidsvormgeving, afspeelmotor,
/// buffering/catch-up en hoe vaak zenderlijst/gids ververst worden. Zie
/// `IPTVPlaybackSettings.swift` (Shared) voor wat er nu al werkt en wat nog
/// een stub is — momenteel is dat alles behalve gidsthema en de landcode-
/// schakelaar: er bestaat nog geen zenderlijst-/gidscache, afspeelmotor-
/// keuze of FPS-teller in Veyra.
///
/// Was één lange lijst met vier secties; voor meer overzicht nu een
/// categoriemenu naar kleine subschermen — zelfde patroon als
/// `PlaybackSettingsView`/`SettingsView`.
struct IPTVPlaybackSettingsView: View {
    @State private var destination: IPTVPlaybackDestination?

    var body: some View {
        ZStack {
            VeyraBackground().ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 18) {
                    categoryCard(
                        .guide, icon: "tv.badge.wifi", title: "Zenderguide",
                        subtitle: "Gidsthema, zendernamen"
                    )
                    categoryCard(
                        .playback, icon: "play.laptopcomputer", title: "Afspelen",
                        subtitle: "Afspeelmotor, buffering, catch-up"
                    )
                    categoryCard(
                        .cache, icon: "arrow.triangle.2.circlepath", title: "Cache & verversen",
                        subtitle: "Zenderlijst en programmagids"
                    )
                    categoryCard(
                        .developer, icon: "ladybug", title: "Ontwikkelaarsopties",
                        subtitle: "FPS-teller"
                    )
                }
                .frame(maxWidth: 1300, alignment: .leading)
                .padding(.horizontal, VeyraSpacing.page)
                .padding(.top, 36)
                .padding(.bottom, 60)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Live TV")
        .navigationDestination(item: $destination) { destination in
            switch destination {
            case .guide: IPTVGuideSettingsView()
            case .playback: IPTVEnginePlaybackSettingsView()
            case .cache: IPTVCacheSettingsView()
            case .developer: IPTVDeveloperSettingsView()
            }
        }
    }

    private func categoryCard(
        _ target: IPTVPlaybackDestination,
        icon: String,
        title: String,
        subtitle: String
    ) -> some View {
        Button {
            destination = target
        } label: {
            HStack(spacing: 24) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(VeyraColors.cyan.opacity(0.14))

                    Image(systemName: icon)
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(VeyraColors.cyan)
                }
                .frame(width: 68, height: 68)

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.system(size: 20))
                        .foregroundStyle(.white.opacity(0.60))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(20)
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(VeyraFocusButtonStyle(radius: 22))
    }
}

private enum IPTVPlaybackDestination: String, Identifiable, Hashable {
    case guide, playback, cache, developer

    var id: String { rawValue }
}

// MARK: - Zenderguide

private struct IPTVGuideSettingsView: View {
    @AppStorage(IPTVPlaybackSettingsDefaults.guideThemeKey)
    private var guideThemeRaw = IPTVGuideTheme.colourful.rawValue
    @AppStorage(IPTVPlaybackSettingsDefaults.hideCountryPrefixKey)
    private var hideCountryPrefix = true

    var body: some View {
        ZStack {
            VeyraBackground().ignoresSafeArea()

            List {
                Section {
                    Picker("Gidsthema", selection: $guideThemeRaw) {
                        ForEach(IPTVGuideTheme.allCases) { theme in
                            Text(theme.title).tag(theme.rawValue)
                        }
                    }
                    Toggle("Landcode voor zendernaam verbergen", isOn: $hideCountryPrefix)
                } footer: {
                    Text("Gidsthema past de kleuren van de programmagids aan. Bij ingeschakeld wordt de landcode voor zendernamen weggelaten.")
                }
            }
        }
        .navigationTitle("Zenderguide")
    }
}

// MARK: - Afspelen

private struct IPTVEnginePlaybackSettingsView: View {
    @AppStorage(IPTVPlaybackSettingsDefaults.playerEngineKey)
    private var playerEngineRaw = IPTVPlayerEngineOption.intern.rawValue
    @AppStorage(IPTVPlaybackSettingsDefaults.bufferDurationKey)
    private var bufferDurationRaw = IPTVBufferDurationOption.none.rawValue
    @AppStorage(IPTVPlaybackSettingsDefaults.catchUpOffsetModeKey)
    private var catchUpOffsetModeRaw = IPTVCatchUpOffsetMode.automatic.rawValue
    @AppStorage(IPTVPlaybackSettingsDefaults.catchUpOffsetManualSecondsKey)
    private var catchUpOffsetManualSeconds = 0

    private var catchUpOffsetMode: IPTVCatchUpOffsetMode {
        IPTVCatchUpOffsetMode(rawValue: catchUpOffsetModeRaw) ?? .automatic
    }

    var body: some View {
        ZStack {
            VeyraBackground().ignoresSafeArea()

            List {
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
                    // .menu: deze rij wordt direct gevolgd door een rij die
                    // in-/uitklapt zodra de keuze verandert. Zie de zelfde
                    // fix + toelichting in MetadataSettingsView.swift.
                    .pickerStyle(.menu)

                    if catchUpOffsetMode == .manual {
                        // `Stepper` bestaat niet op tvOS — hier vervangen
                        // door een eigen +/- rij.
                        HStack {
                            Text("Correctie: \(catchUpOffsetManualSeconds) sec")
                            Spacer()
                            Button {
                                catchUpOffsetManualSeconds = max(-3600, catchUpOffsetManualSeconds - 60)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            Button {
                                catchUpOffsetManualSeconds = min(3600, catchUpOffsetManualSeconds + 60)
                            } label: {
                                Image(systemName: "plus.circle")
                            }
                        }
                    }
                } footer: {
                    Text("Afspeelmotor bepaalt welke engine live-zenders afspeelt. Buffering: hoeveel live video vooraf klaarstaat. Catch-up-tijdcorrectie volgt normaal de klok van de provider, of stel 'm handmatig in. Nog niet aangesloten op de speler.")
                }
            }
        }
        .navigationTitle("Afspelen")
    }
}

// MARK: - Cache & verversen

private struct IPTVCacheSettingsView: View {
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

                    Button("Zenderlijst-cache wissen") {
                        cacheAlertMessage = "Er is nog geen zenderlijst-cache in Veyra om te wissen."
                    }
                    Button("Gidscache wissen") {
                        cacheAlertMessage = "Er is nog geen gidscache in Veyra om te wissen."
                    }
                } footer: {
                    Text("Veyra heeft nog geen zenderlijst- of gidscache, dus deze instellingen en knoppen doen voorlopig niets.")
                }
            }
        }
        .navigationTitle("Cache & verversen")
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

// MARK: - Ontwikkelaarsopties

private struct IPTVDeveloperSettingsView: View {
    @AppStorage(IPTVPlaybackSettingsDefaults.showFPSCounterKey)
    private var showFPSCounter = false

    var body: some View {
        ZStack {
            VeyraBackground().ignoresSafeArea()

            List {
                Section {
                    Toggle("FPS-teller tonen", isOn: $showFPSCounter)
                } footer: {
                    Text("Er is nog geen FPS-teller in Veyra; deze schakelaar heeft voorlopig geen effect.")
                }
            }
        }
        .navigationTitle("Ontwikkelaarsopties")
    }
}

#Preview {
    NavigationStack { IPTVPlaybackSettingsView() }
}
