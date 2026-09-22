import SwiftUI

/// tvOS-versie van de "Afspelen"-instellingen, zoals Strand die aanbiedt.
/// Zie `PlaybackSettings.swift` (Shared) voor de opgeslagen sleutels en
/// keuzelijsten. De meeste schakelaars sturen de speler nu ook echt aan
/// (eerste bron/details overslaan, taalvoorkeuren, oversla-segmenten,
/// "hierna"). Nog niet aangesloten: voorkeursresolutie/mobiele resolutie
/// (AetherEngine's laadopties bieden hier vooralsnog geen haakje voor),
/// anime-audio, melding na de aftiteling, externe speler en "automatisch
/// draaien naar liggend" (niet van toepassing op tvOS).
///
/// Dit scherm was voorheen één lange lijst met ruim twintig schakelaars.
/// Voor meer overzicht (zie ook het hoofdmenu "Instellingen") is dat nu
/// een categoriemenu dat naar kleine, gefocuste subschermen doorverwijst —
/// zelfde patroon als `SettingsView`.
struct PlaybackSettingsView: View {
    @State private var destination: PlaybackSettingsDestination?

    var body: some View {
        ZStack {
            VeyraBackground().ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 18) {
                    categoryCard(
                        .general, icon: "play.circle", title: "Afspelen",
                        subtitle: "Draaien, bronkeuze, verdergaan, resolutie"
                    )
                    categoryCard(
                        .loadingScreen, icon: "hourglass", title: "Laadscherm",
                        subtitle: "Voortgangsbalk"
                    )
                    categoryCard(
                        .language, icon: "captions.bubble", title: "Taal",
                        subtitle: "Audio- en ondertiteltaal"
                    )
                    categoryCard(
                        .skipSegments, icon: "forward.end.alt", title: "Oversla-segmenten",
                        subtitle: "Intro, samenvatting, aftiteling"
                    )
                    categoryCard(
                        .upNext, icon: "play.square.stack", title: "Hierna",
                        subtitle: "Automatisch doorspelen en aftelling"
                    )
                    categoryCard(
                        .player, icon: "tv", title: "Speler",
                        subtitle: "Interne of externe speler"
                    )
                }
                .frame(maxWidth: 1300, alignment: .leading)
                .padding(.horizontal, VeyraSpacing.page)
                .padding(.top, 36)
                .padding(.bottom, 60)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Afspelen")
        .navigationDestination(item: $destination) { destination in
            switch destination {
            case .general: PlaybackGeneralSettingsView()
            case .loadingScreen: PlaybackLoadingScreenSettingsView()
            case .language: PlaybackLanguageSettingsView()
            case .skipSegments: PlaybackSkipSegmentsSettingsView()
            case .upNext: PlaybackUpNextSettingsView()
            case .player: PlaybackPlayerSettingsView()
            }
        }
    }

    // MARK: - Categoriekaart

    private func categoryCard(
        _ target: PlaybackSettingsDestination,
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

private enum PlaybackSettingsDestination: String, Identifiable, Hashable {
    case general, loadingScreen, language, skipSegments, upNext, player

    var id: String { rawValue }
}

// MARK: - Afspelen

private struct PlaybackGeneralSettingsView: View {
    @AppStorage(PlaybackSettingsDefaults.autoRotateLandscapeKey)
    private var autoRotateLandscape = true
    @AppStorage(PlaybackSettingsDefaults.autoPlayNextEpisodeKey)
    private var autoPlayNextEpisode = true
    @AppStorage(PlaybackSettingsDefaults.autoSelectFirstSourceKey)
    private var autoSelectFirstSource = false
    @AppStorage(PlaybackSettingsDefaults.skipContinueWatchingDetailsKey)
    private var skipContinueWatchingDetails = false
    @AppStorage(PlaybackSettingsDefaults.preferredResolutionKey)
    private var preferredResolutionRaw = PlaybackResolutionOption.highest.rawValue
    @AppStorage(PlaybackSettingsDefaults.cellularResolutionKey)
    private var cellularResolutionRaw = PlaybackCellularResolutionOption.fullHD1080.rawValue

    var body: some View {
        ZStack {
            VeyraBackground().ignoresSafeArea()

            List {
                Section {
                    Toggle("Automatisch draaien naar liggend", isOn: $autoRotateLandscape)
                    Toggle("Volgende aflevering automatisch afspelen", isOn: $autoPlayNextEpisode)
                    Toggle("Eerste bron automatisch selecteren", isOn: $autoSelectFirstSource)
                    Toggle("Details overslaan bij verdergaan", isOn: $skipContinueWatchingDetails)

                    Picker("Voorkeursresolutie", selection: $preferredResolutionRaw) {
                        ForEach(PlaybackResolutionOption.allCases) { option in
                            Text(option.title).tag(option.rawValue)
                        }
                    }

                    Picker("Resolutie via mobiele data", selection: $cellularResolutionRaw) {
                        ForEach(PlaybackCellularResolutionOption.allCases) { option in
                            Text(option.title).tag(option.rawValue)
                        }
                    }
                } footer: {
                    Text("HDR en Dolby Vision worden automatisch herkend en afgespeeld door de speler — daar is geen instelling voor nodig. Voorkeursresolutie en resolutie via mobiele data zijn nog niet aangesloten op de speler.")
                }
            }
        }
        .navigationTitle("Afspelen")
    }
}

// MARK: - Laadscherm

private struct PlaybackLoadingScreenSettingsView: View {
    @AppStorage(PlaybackSettingsDefaults.hideProgressBarKey)
    private var hideProgressBar = false

    var body: some View {
        ZStack {
            VeyraBackground().ignoresSafeArea()

            List {
                Section {
                    Toggle("Voortgangsbalk verbergen", isOn: $hideProgressBar)
                }
            }
        }
        .navigationTitle("Laadscherm")
    }
}

// MARK: - Taal

private struct PlaybackLanguageSettingsView: View {
    @AppStorage(PlaybackSettingsDefaults.audioLanguageKey)
    private var audioLanguageRaw = PlaybackLanguageOption.original.rawValue
    @AppStorage(PlaybackSettingsDefaults.audioFallbackLanguageKey)
    private var audioFallbackLanguageRaw = PlaybackLanguageOption.english.rawValue
    @AppStorage(PlaybackSettingsDefaults.subtitleLanguageKey)
    private var subtitleLanguageRaw = PlaybackLanguageOption.dutch.rawValue
    @AppStorage(PlaybackSettingsDefaults.subtitleFallbackLanguageKey)
    private var subtitleFallbackLanguageRaw = PlaybackLanguageOption.english.rawValue
    @AppStorage(PlaybackSettingsDefaults.autoSelectSubtitlesKey)
    private var autoSelectSubtitlesRaw = PlaybackAutoSelectSubtitlesOption.forcedOnly.rawValue
    @AppStorage(PlaybackSettingsDefaults.animeAudioKey)
    private var animeAudioRaw = PlaybackAnimeAudioOption.noPreference.rawValue

    var body: some View {
        ZStack {
            VeyraBackground().ignoresSafeArea()

            List {
                Section {
                    Picker("Audiotaal", selection: $audioLanguageRaw) {
                        ForEach(PlaybackLanguageOption.allCases) { option in
                            Text(option.title).tag(option.rawValue)
                        }
                    }
                    Picker("Audiotaal (terugval)", selection: $audioFallbackLanguageRaw) {
                        ForEach(PlaybackLanguageOption.allCases) { option in
                            Text(option.title).tag(option.rawValue)
                        }
                    }
                } header: {
                    Text("Audio")
                }

                Section {
                    Picker("Ondertiteltaal", selection: $subtitleLanguageRaw) {
                        ForEach(PlaybackLanguageOption.allCases) { option in
                            Text(option.title).tag(option.rawValue)
                        }
                    }
                    Picker("Ondertiteltaal (terugval)", selection: $subtitleFallbackLanguageRaw) {
                        ForEach(PlaybackLanguageOption.allCases) { option in
                            Text(option.title).tag(option.rawValue)
                        }
                    }
                    Picker("Ondertitels automatisch selecteren", selection: $autoSelectSubtitlesRaw) {
                        ForEach(PlaybackAutoSelectSubtitlesOption.allCases) { option in
                            Text(option.title).tag(option.rawValue)
                        }
                    }
                } header: {
                    Text("Ondertitels")
                }

                Section {
                    Picker("Anime-audio", selection: $animeAudioRaw) {
                        ForEach(PlaybackAnimeAudioOption.allCases) { option in
                            Text(option.title).tag(option.rawValue)
                        }
                    }
                } footer: {
                    Text("Anime-audio is nog niet aangesloten op de speler.")
                }
            }
        }
        .navigationTitle("Taal")
    }
}

// MARK: - Oversla-segmenten

private struct PlaybackSkipSegmentsSettingsView: View {
    @AppStorage(PlaybackSettingsDefaults.showSkipIntroButtonKey)
    private var showSkipIntroButton = true
    @AppStorage(PlaybackSettingsDefaults.autoSkipIntroKey)
    private var autoSkipIntro = false
    @AppStorage(PlaybackSettingsDefaults.showSkipRecapButtonKey)
    private var showSkipRecapButton = true
    @AppStorage(PlaybackSettingsDefaults.showSkipCreditsButtonKey)
    private var showSkipCreditsButton = true
    @AppStorage(PlaybackSettingsDefaults.postCreditsAlertKey)
    private var postCreditsAlert = false

    var body: some View {
        ZStack {
            VeyraBackground().ignoresSafeArea()

            List {
                Section {
                    Toggle("Knop 'Intro overslaan' tonen", isOn: $showSkipIntroButton)
                    Toggle("Intro automatisch overslaan", isOn: $autoSkipIntro)
                    Toggle("Knop 'Samenvatting overslaan' tonen", isOn: $showSkipRecapButton)
                    Toggle("Knop 'Aftiteling overslaan' tonen", isOn: $showSkipCreditsButton)
                    Toggle("Melding na de aftiteling", isOn: $postCreditsAlert)
                } footer: {
                    Text("Tijden komen van TheIntroDB en zijn niet voor elke film of aflevering beschikbaar. Melding na de aftiteling is nog niet aangesloten op de speler.")
                }
            }
        }
        .navigationTitle("Oversla-segmenten")
    }
}

// MARK: - Hierna

private struct PlaybackUpNextSettingsView: View {
    @AppStorage(PlaybackSettingsDefaults.autoPlayNextCountdownEnabledKey)
    private var autoPlayNextCountdownEnabled = true
    @AppStorage(PlaybackSettingsDefaults.countdownDurationKey)
    private var countdownDurationRaw = PlaybackCountdownDuration.ten.rawValue

    var body: some View {
        ZStack {
            VeyraBackground().ignoresSafeArea()

            List {
                Section {
                    Toggle("Aftelling voor volgende aflevering", isOn: $autoPlayNextCountdownEnabled)

                    Picker("Duur van de aftelling", selection: $countdownDurationRaw) {
                        ForEach(PlaybackCountdownDuration.allCases) { option in
                            Text(option.title).tag(option.rawValue)
                        }
                    }
                    .disabled(!autoPlayNextCountdownEnabled)
                }
            }
        }
        .navigationTitle("Hierna")
    }
}

// MARK: - Speler

private struct PlaybackPlayerSettingsView: View {
    @AppStorage(PlaybackSettingsDefaults.selectedPlayerKey)
    private var selectedPlayerRaw = PlaybackSelectedPlayer.intern.rawValue

    var body: some View {
        ZStack {
            VeyraBackground().ignoresSafeArea()

            List {
                Section {
                    Picker("Speler geselecteerd", selection: $selectedPlayerRaw) {
                        ForEach(PlaybackSelectedPlayer.allCases) { option in
                            Text(option.title).tag(option.rawValue)
                        }
                    }
                } footer: {
                    Text("Externe spelerondersteuning hangt af van wat AetherEngine toestaat en is hier nog niet aangesloten.")
                }
            }
        }
        .navigationTitle("Speler")
    }
}

#Preview {
    NavigationStack { PlaybackSettingsView() }
}
