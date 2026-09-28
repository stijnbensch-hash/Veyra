import SwiftUI

/// tvOS-versie van de "Afspelen"-instellingen, zoals Strand die aanbiedt.
/// Zie `PlaybackSettings.swift` (Shared) voor de opgeslagen sleutels en
/// keuzelijsten. De schakelaars sturen de speler nu ook echt aan (eerste
/// bron/details overslaan, taalvoorkeuren, oversla-segmenten, "hierna").
/// Instellingen die nog geen haakje in de speler hadden (voorkeursresolutie,
/// anime-audio, melding na de aftiteling, externe speler) zijn verwijderd
/// i.p.v. als dode schakelaar te blijven staan.
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
            case .language: PlaybackLanguageSettingsView()
            case .skipSegments: PlaybackSkipSegmentsSettingsView()
            case .upNext: PlaybackUpNextSettingsView()
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
    case general, language, skipSegments, upNext

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

    var body: some View {
        ZStack {
            VeyraBackground().ignoresSafeArea()

            List {
                Section {
                    VeyraSettingsToggleRow(icon: "rotate.right", title: "Automatisch draaien naar liggend", isOn: $autoRotateLandscape)
                    VeyraSettingsToggleRow(icon: "play.fill", title: "Volgende aflevering automatisch afspelen", isOn: $autoPlayNextEpisode)
                    VeyraSettingsToggleRow(icon: "checkmark.circle", title: "Eerste bron automatisch selecteren", isOn: $autoSelectFirstSource)
                    VeyraSettingsToggleRow(icon: "forward.end", title: "Details overslaan bij verdergaan", isOn: $skipContinueWatchingDetails)
                } footer: {
                    Text("HDR en Dolby Vision worden automatisch herkend en afgespeeld door de speler — daar is geen instelling voor nodig.")
                }
            }
            .frame(maxWidth: 1000)
        }
        .navigationTitle("Afspelen")
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

    var body: some View {
        ZStack {
            VeyraBackground().ignoresSafeArea()

            List {
                Section {
                    VeyraSettingsChoiceRow<PlaybackLanguageOption>(icon: "waveform", "Audiotaal", selection: $audioLanguageRaw)
                    VeyraSettingsChoiceRow<PlaybackLanguageOption>(icon: "waveform", "Audiotaal (terugval)", selection: $audioFallbackLanguageRaw)
                } header: {
                    Text("Audio")
                }

                Section {
                    VeyraSettingsChoiceRow<PlaybackLanguageOption>(icon: "captions.bubble", "Ondertiteltaal", selection: $subtitleLanguageRaw)
                    VeyraSettingsChoiceRow<PlaybackLanguageOption>(icon: "captions.bubble", "Ondertiteltaal (terugval)", selection: $subtitleFallbackLanguageRaw)
                    VeyraSettingsChoiceRow<PlaybackAutoSelectSubtitlesOption>(icon: "checkmark.bubble", "Ondertitels automatisch selecteren", selection: $autoSelectSubtitlesRaw)
                } header: {
                    Text("Ondertitels")
                }
            }
            .frame(maxWidth: 1000)
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

    var body: some View {
        ZStack {
            VeyraBackground().ignoresSafeArea()

            List {
                Section {
                    VeyraSettingsToggleRow(icon: "forward.frame", title: "Knop 'Intro overslaan' tonen", isOn: $showSkipIntroButton)
                    VeyraSettingsToggleRow(icon: "bolt.fill", title: "Intro automatisch overslaan", isOn: $autoSkipIntro)
                    VeyraSettingsToggleRow(icon: "arrow.uturn.forward", title: "Knop 'Samenvatting overslaan' tonen", isOn: $showSkipRecapButton)
                    VeyraSettingsToggleRow(icon: "text.below.photo", title: "Knop 'Aftiteling overslaan' tonen", isOn: $showSkipCreditsButton)
                } footer: {
                    Text("Tijden komen van TheIntroDB en zijn niet voor elke film of aflevering beschikbaar.")
                }
            }
            .frame(maxWidth: 1000)
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
                    VeyraSettingsToggleRow(icon: "timer", title: "Aftelling voor volgende aflevering", isOn: $autoPlayNextCountdownEnabled)

                    VeyraSettingsChoiceRow<PlaybackCountdownDuration>(icon: "timer", "Duur van de aftelling", selection: $countdownDurationRaw)
                    .disabled(!autoPlayNextCountdownEnabled)
                }
            }
            .frame(maxWidth: 1000)
        }
        .navigationTitle("Hierna")
    }
}

#Preview {
    NavigationStack { PlaybackSettingsView() }
}
