import SwiftUI

/// "Afspelen"-instellingen, zoals Strand die aanbiedt. Zie
/// `PlaybackSettings.swift` (Shared) voor de opgeslagen sleutels en
/// keuzelijsten, en voor de status: dit scherm legt alleen de instellingen
/// zelf vast (UI + opslag) — geen van deze schakelaars stuurt vandaag al de
/// speler (`AetherEngine`) aan.
struct PlaybackSettingsView: View {
    // Afspelen
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

    // Loading screen
    @AppStorage(PlaybackSettingsDefaults.hideProgressBarKey)
    private var hideProgressBar = false

    // Taal
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

    // Oversla-segmenten
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

    // Hierna
    @AppStorage(PlaybackSettingsDefaults.autoPlayNextCountdownEnabledKey)
    private var autoPlayNextCountdownEnabled = true
    @AppStorage(PlaybackSettingsDefaults.countdownDurationKey)
    private var countdownDurationRaw = PlaybackCountdownDuration.ten.rawValue

    // Speler
    @AppStorage(PlaybackSettingsDefaults.selectedPlayerKey)
    private var selectedPlayerRaw = PlaybackSelectedPlayer.intern.rawValue

    var body: some View {
        ZStack {
            VeyraColors.background.ignoresSafeArea()

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
                } header: {
                    Text("Afspelen")
                } footer: {
                    Text("HDR en Dolby Vision worden automatisch herkend en afgespeeld door de speler — daar is geen instelling voor nodig.")
                }

                Section {
                    Toggle("Voortgangsbalk verbergen", isOn: $hideProgressBar)
                } header: {
                    Text("Laadscherm")
                }

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
                    Picker("Anime-audio", selection: $animeAudioRaw) {
                        ForEach(PlaybackAnimeAudioOption.allCases) { option in
                            Text(option.title).tag(option.rawValue)
                        }
                    }
                } header: {
                    Text("Taal")
                }

                Section {
                    Toggle("Knop 'Intro overslaan' tonen", isOn: $showSkipIntroButton)
                    Toggle("Intro automatisch overslaan", isOn: $autoSkipIntro)
                    Toggle("Knop 'Samenvatting overslaan' tonen", isOn: $showSkipRecapButton)
                    Toggle("Knop 'Aftiteling overslaan' tonen", isOn: $showSkipCreditsButton)
                    Toggle("Melding na de aftiteling", isOn: $postCreditsAlert)
                } header: {
                    Text("Oversla-segmenten")
                } footer: {
                    Text("Tijden komen van TheIntroDB en zijn niet voor elke film of aflevering beschikbaar. Melding na de aftiteling is nog niet aangesloten op de speler.")
                }

                Section {
                    Toggle("Aftelling voor volgende aflevering", isOn: $autoPlayNextCountdownEnabled)

                    Picker("Duur van de aftelling", selection: $countdownDurationRaw) {
                        ForEach(PlaybackCountdownDuration.allCases) { option in
                            Text(option.title).tag(option.rawValue)
                        }
                    }
                    .disabled(!autoPlayNextCountdownEnabled)
                } header: {
                    Text("Hierna")
                }

                Section {
                    Picker("Speler geselecteerd", selection: $selectedPlayerRaw) {
                        ForEach(PlaybackSelectedPlayer.allCases) { option in
                            Text(option.title).tag(option.rawValue)
                        }
                    }
                } header: {
                    Text("Speler")
                } footer: {
                    Text("Externe spelerondersteuning hangt af van wat AetherEngine toestaat en is hier nog niet aangesloten.")
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Afspelen")
    }
}

#Preview {
    NavigationStack { PlaybackSettingsView() }
}
