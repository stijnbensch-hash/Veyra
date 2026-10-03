import SwiftUI

/// "Afspelen"-instellingen, zoals Strand die aanbiedt. Zie
/// `PlaybackSettings.swift` (Shared) voor de opgeslagen sleutels en
/// keuzelijsten. De schakelaars sturen de speler nu ook echt aan
/// (automatisch draaien, eerste bron/details overslaan, taalvoorkeuren,
/// oversla-segmenten, "hierna"). Instellingen die nog geen haakje in de
/// speler hadden (voorkeursresolutie, anime-audio, melding na de aftiteling,
/// externe speler) zijn verwijderd i.p.v. als dode schakelaar te blijven
/// staan.
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

    // Oversla-segmenten
    @AppStorage(PlaybackSettingsDefaults.showSkipIntroButtonKey)
    private var showSkipIntroButton = true
    @AppStorage(PlaybackSettingsDefaults.autoSkipIntroKey)
    private var autoSkipIntro = false
    @AppStorage(PlaybackSettingsDefaults.showSkipRecapButtonKey)
    private var showSkipRecapButton = true
    @AppStorage(PlaybackSettingsDefaults.showSkipCreditsButtonKey)
    private var showSkipCreditsButton = true
    @AppStorage(PlaybackSettingsDefaults.showSkipPreviewButtonKey)
    private var showSkipPreviewButton = true
    @AppStorage(PlaybackSettingsDefaults.autoSkipRecapKey)
    private var autoSkipRecap = false
    @AppStorage(PlaybackSettingsDefaults.autoSkipCreditsKey)
    private var autoSkipCredits = false
    @AppStorage(PlaybackSettingsDefaults.autoSkipPreviewKey)
    private var autoSkipPreview = false

    // Hierna
    @AppStorage(PlaybackSettingsDefaults.autoPlayNextCountdownEnabledKey)
    private var autoPlayNextCountdownEnabled = true
    @AppStorage(PlaybackSettingsDefaults.countdownDurationKey)
    private var countdownDurationRaw = PlaybackCountdownDuration.ten.rawValue

    var body: some View {
        VeyraDynamicBackgroundScope {
            ZStack {
                VeyraBackground().ignoresSafeArea()

                VeyraList {
                    Section {
                        Toggle("Automatisch draaien naar liggend", isOn: $autoRotateLandscape)
                        Toggle("Volgende aflevering automatisch afspelen", isOn: $autoPlayNextEpisode)
                        Toggle("Eerste bron automatisch selecteren", isOn: $autoSelectFirstSource)
                        Toggle("Details overslaan bij verdergaan", isOn: $skipContinueWatchingDetails)
                    } header: {
                        Text("Afspelen")
                    } footer: {
                        Text("HDR en Dolby Vision worden automatisch herkend en afgespeeld door de speler — daar is geen instelling voor nodig.")
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
                    } header: {
                        Text("Taal")
                    }

                    Section {
                        Toggle("Knop 'Intro overslaan' tonen", isOn: $showSkipIntroButton)
                        Toggle("Intro automatisch overslaan", isOn: $autoSkipIntro)
                        Toggle("Knop 'Samenvatting overslaan' tonen", isOn: $showSkipRecapButton)
                        Toggle("Samenvatting automatisch overslaan", isOn: $autoSkipRecap)
                        Toggle("Knop 'Aftiteling overslaan' tonen", isOn: $showSkipCreditsButton)
                        Toggle("Aftiteling automatisch overslaan", isOn: $autoSkipCredits)
                        Toggle("Knop 'Preview overslaan' tonen", isOn: $showSkipPreviewButton)
                        Toggle("Preview automatisch overslaan", isOn: $autoSkipPreview)
                    } header: {
                        Text("Oversla-segmenten")
                    } footer: {
                        Text("Automatisch overslaan gebeurt alleen bij voldoende betrouwbare tijden. Tijden zijn niet voor elke film of aflevering beschikbaar.")
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
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Afspelen")

        }
    }
}

#Preview {
    NavigationStack { PlaybackSettingsView() }
}
