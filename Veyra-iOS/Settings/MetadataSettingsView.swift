import SwiftUI

struct MetadataSettingsView: View {
    @AppStorage("metadata.source.preference") private var metadataSourceRaw = MetadataSourceOption.tmdb.rawValue

    @AppStorage(PosterEnrichmentDefaults.modeKey)
    private var posterEnrichmentSourceRaw = PosterEnrichmentMode.off.rawValue
    @AppStorage(PosterEnrichmentDefaults.showGenreKey)
    private var posterShowGenre = true
    @AppStorage(PosterEnrichmentDefaults.showRatingKey)
    private var posterShowRating = true
    @AppStorage(PosterEnrichmentDefaults.ratingSourceKey)
    private var posterRatingSourceRaw = PosterRatingSource.tmdb.rawValue
    @AppStorage(PosterEnrichmentDefaults.showAgeRatingKey)
    private var posterShowAgeRating = false
    @AppStorage(PosterEnrichmentDefaults.showQualityLabelsKey)
    private var posterShowQuality = false
    @AppStorage(PosterEnrichmentDefaults.showTrendLabelsKey)
    private var posterShowTrending = false
    @AppStorage(PosterEnrichmentDefaults.showEpisodesRemainingKey)
    private var posterShowEpisodesRemaining = false

    private var posterEnrichmentSource: PosterEnrichmentMode {
        PosterEnrichmentMode(rawValue: posterEnrichmentSourceRaw) ?? .off
    }

    @AppStorage(MetadataRatingProvider.imdb.storageKey) private var imdb = true
    @AppStorage(MetadataRatingProvider.tmdb.storageKey) private var tmdb = true
    @AppStorage(MetadataRatingProvider.tomatometer.storageKey) private var tomatometer = true
    @AppStorage(MetadataRatingProvider.metacritic.storageKey) private var metacritic = true
    @AppStorage(MetadataRatingProvider.trakt.storageKey) private var trakt = true
    @AppStorage(MetadataRatingProvider.popcornmeter.storageKey) private var popcornmeter = true

    var body: some View {
        ZStack {
            VeyraColors.background.ignoresSafeArea()

            List {
                Section {
                    Picker("Bron", selection: $posterEnrichmentSourceRaw) {
                        ForEach(PosterEnrichmentMode.allCases) { option in
                            Text(option.title).tag(option.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)

                    if posterEnrichmentSource != .off {
                        HStack {
                            Spacer()
                            VeyraPosterCard(
                                title: "Voorbeeldfilm",
                                url: nil,
                                width: 100,
                                genre: "Actie",
                                rating: 7.8
                            )
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                    }

                    if posterEnrichmentSource == .betterPosters {
                        Toggle("Genre", isOn: $posterShowGenre)
                        Toggle("Beoordeling", isOn: $posterShowRating)
                        if posterShowRating {
                            Picker("Bron", selection: $posterRatingSourceRaw) {
                                ForEach(PosterRatingSource.allCases) { option in
                                    Text(option.title).tag(option.rawValue)
                                }
                            }
                        }
                        Toggle("Leeftijdsclassificatie", isOn: $posterShowAgeRating)
                        Toggle("Kwaliteitslabels", isOn: $posterShowQuality)
                        Toggle("Trendlabels", isOn: $posterShowTrending)
                        Toggle("Resterende afleveringen", isOn: $posterShowEpisodesRemaining)
                    } else if posterEnrichmentSource == .rpdb {
                        Text("RPDB (ratingposterdb.com) is een externe dienst waarvoor nog geen integratie bestaat — deze keuze doet nog niets. Kies Better Posters voor werkende genre-/beoordelingslabels.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Posterverrijking")
                } footer: {
                    Text("Toont een badge met genre en/of beoordeling op de posters in Films, Series en het startscherm. Genre en Beoordeling via Better Posters werken al echt; Leeftijdsclassificatie, Kwaliteitslabels, Trendlabels en Resterende afleveringen staan klaar maar Veyra haalt die gegevens nog niet op.")
                }

                Section {
                    Picker("Metadatabron", selection: $metadataSourceRaw) {
                        ForEach(MetadataSourceOption.allCases) { option in
                            Text(option.title).tag(option.rawValue)
                        }
                    }
                } header: {
                    Text("Metadatabron")
                } footer: {
                    Text("Bepaalt waar poster, achtergrond en omschrijving vandaan komen voor titels zonder eigen afbeeldingen (bv. Trakt-lijsten). AIOMetadata vereist een addon bij Addons.")
                }

                Section {
                    toggleRow(.imdb, isOn: $imdb)
                    toggleRow(.tmdb, isOn: $tmdb)
                    toggleRow(.tomatometer, isOn: $tomatometer)
                    toggleRow(.metacritic, isOn: $metacritic)
                    toggleRow(.trakt, isOn: $trakt)
                    toggleRow(.popcornmeter, isOn: $popcornmeter)
                } header: {
                    Text("Ratings")
                } footer: {
                    Text("Kies welke ratings zichtbaar zijn op film- en seriepagina's. Een titel toont alleen de scores die de bron er daadwerkelijk voor heeft.")
                }

                Section {
                    Button("Alle ratings inschakelen") { setAll(true) }
                    Button("Alle ratings uitschakelen") { setAll(false) }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Metadata")
    }

    // MARK: - Row

    private func toggleRow(_ provider: MetadataRatingProvider, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(iconBackground(provider))
                        .frame(width: 36, height: 36)

                    Image(systemName: provider.systemImage)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(iconForeground(provider))
                }

                Text(provider.title)
            }
        }
        .tint(VeyraColors.cyan)
    }

    private func iconBackground(_ provider: MetadataRatingProvider) -> Color {
        switch provider {
        case .imdb: return .yellow
        case .tmdb: return .cyan.opacity(0.22)
        case .tomatometer: return .red.opacity(0.22)
        case .metacritic: return .yellow.opacity(0.18)
        case .trakt: return .pink.opacity(0.22)
        case .popcornmeter: return .orange.opacity(0.22)
        }
    }

    private func iconForeground(_ provider: MetadataRatingProvider) -> Color {
        switch provider {
        case .imdb: return .black
        case .tmdb: return .cyan
        case .tomatometer: return .red
        case .metacritic: return .yellow
        case .trakt: return .pink
        case .popcornmeter: return .orange
        }
    }

    // MARK: - Actions

    private func setAll(_ enabled: Bool) {
        imdb = enabled
        tmdb = enabled
        tomatometer = enabled
        metacritic = enabled
        trakt = enabled
        popcornmeter = enabled
    }
}

#Preview {
    NavigationStack { MetadataSettingsView() }
}
