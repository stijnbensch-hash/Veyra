import SwiftUI

struct MetadataSettingsView: View {
    @AppStorage("metadata.source.preference")
    private var metadataSourceRaw = MetadataSourceOption.tmdb.rawValue

    @AppStorage("metadata.rating.imdb")
    private var imdb = true

    @AppStorage("metadata.rating.tmdb")
    private var tmdb = true

    @AppStorage("metadata.rating.tomatometer")
    private var tomatometer = true

    @AppStorage("metadata.rating.metacritic")
    private var metacritic = true

    @AppStorage("metadata.rating.trakt")
    private var trakt = true

    @AppStorage("metadata.rating.popcornmeter")
    private var popcornmeter = true

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

    var body: some View {
        Form {
            Section {
                Picker("Bron", selection: $posterEnrichmentSourceRaw) {
                    ForEach(PosterEnrichmentMode.allCases) { option in
                        Text(option.title).tag(option.rawValue)
                    }
                }

                if posterEnrichmentSource != .off {
                    HStack {
                        Spacer()
                        VeyraPosterCard(
                            title: "Voorbeeldfilm",
                            url: nil,
                            width: 220,
                            genre: "Actie",
                            rating: 7.8
                        )
                        Spacer()
                    }
                }

                if posterEnrichmentSource == .betterPosters {
                    Toggle("Genre", isOn: $posterShowGenre)
                    Toggle("Beoordeling", isOn: $posterShowRating)
                    if posterShowRating {
                        Picker("Bron beoordeling", selection: $posterRatingSourceRaw) {
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
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Posterverrijking")
            } footer: {
                Text("Toont een badge met genre en/of beoordeling op de posters in Films, Series en het startscherm. Genre en Beoordeling via Better Posters werken al echt; Leeftijdsclassificatie, Kwaliteitslabels, Trendlabels en Resterende afleveringen staan klaar maar Veyra haalt die gegevens nog niet op.")
            }

            Section {
                Picker(
                    "Metadatabron",
                    selection: $metadataSourceRaw
                ) {
                    ForEach(MetadataSourceOption.allCases) { option in
                        Text(option.title).tag(option.rawValue)
                    }
                }
            } header: {
                Text("Metadatabron")
            } footer: {
                Text(
                    "Bepaalt waar poster, achtergrond en omschrijving vandaan komen voor titels zonder eigen afbeeldingen (bv. Trakt-lijsten). AIOMetadata vereist een addon bij Addons."
                )
            }

            Section {
                Toggle(
                    isOn: $imdb
                ) {
                    providerRow(
                        .imdb
                    )
                }

                Toggle(
                    isOn: $tmdb
                ) {
                    providerRow(
                        .tmdb
                    )
                }

                Toggle(
                    isOn: $tomatometer
                ) {
                    providerRow(
                        .tomatometer
                    )
                }

                Toggle(
                    isOn: $metacritic
                ) {
                    providerRow(
                        .metacritic
                    )
                }

                Toggle(
                    isOn: $trakt
                ) {
                    providerRow(
                        .trakt
                    )
                }

                Toggle(
                    isOn: $popcornmeter
                ) {
                    providerRow(
                        .popcornmeter
                    )
                }

            } header: {
                Text(
                    "Ratings"
                )

            } footer: {
                Text(
                    "Kies welke ratings zichtbaar zijn op film- en seriepagina's."
                )
            }

            Section {
                Button(
                    "Alle ratings inschakelen"
                ) {
                    enableAll()
                }

                Button(
                    "Alle ratings uitschakelen"
                ) {
                    disableAll()
                }

                Button(
                    "Standaardinstellingen herstellen"
                ) {
                    resetDefaults()
                }
            }
        }
        .navigationTitle(
            "Metadata"
        )
    }

    // MARK: - Provider Row

    @ViewBuilder
    private func providerRow(
        _ provider:
            MetadataRatingProvider
    ) -> some View {
        HStack(
            spacing: 16
        ) {
            providerIcon(
                provider
            )

            Text(
                provider.title
            )
            .font(
                .system(
                    size: 22,
                    weight: .medium,
                    design: .rounded
                )
            )
        }
    }

    // MARK: - Provider Icon

    @ViewBuilder
    private func providerIcon(
        _ provider:
            MetadataRatingProvider
    ) -> some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: 8,
                style: .continuous
            )
            .fill(
                iconBackground(
                    provider
                )
            )
            .frame(
                width: 44,
                height: 44
            )

            Image(
                systemName:
                    provider.systemImage
            )
            .font(
                .system(
                    size: 20,
                    weight: .bold
                )
            )
            .foregroundStyle(
                iconForeground(
                    provider
                )
            )
        }
    }

    private func iconBackground(
        _ provider:
            MetadataRatingProvider
    ) -> Color {
        switch provider {
        case .imdb:
            return .yellow

        case .tmdb:
            return .cyan.opacity(0.22)

        case .tomatometer:
            return .red.opacity(0.22)

        case .metacritic:
            return .yellow.opacity(0.18)

        case .trakt:
            return .pink.opacity(0.22)

        case .popcornmeter:
            return .orange.opacity(0.22)
        }
    }

    private func iconForeground(
        _ provider:
            MetadataRatingProvider
    ) -> Color {
        switch provider {
        case .imdb:
            return .black

        case .tmdb:
            return .cyan

        case .tomatometer:
            return .red

        case .metacritic:
            return .yellow

        case .trakt:
            return .pink

        case .popcornmeter:
            return .orange
        }
    }

    // MARK: - Actions

    private func enableAll() {
        imdb = true
        tmdb = true
        tomatometer = true
        metacritic = true
        trakt = true
        popcornmeter = true
    }

    private func disableAll() {
        imdb = false
        tmdb = false
        tomatometer = false
        metacritic = false
        trakt = false
        popcornmeter = false
    }

    private func resetDefaults() {
        enableAll()
    }
}

#Preview {
    NavigationStack {
        MetadataSettingsView()
    }
}
