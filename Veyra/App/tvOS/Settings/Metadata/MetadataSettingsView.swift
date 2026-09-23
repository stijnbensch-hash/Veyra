import SwiftUI

/// Was één lange lijst met vier secties; voor meer overzicht nu een
/// categoriemenu naar kleine subschermen — zelfde patroon als
/// `PlaybackSettingsView`/`SettingsView`.
struct MetadataSettingsView: View {
    @State private var destination: MetadataSettingsDestination?

    var body: some View {
        ZStack {
            VeyraBackground().ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 18) {
                    categoryCard(
                        .posterEnrichment, icon: "photo.badge.checkmark", title: "Posterverrijking",
                        subtitle: "Genre-/beoordelingsbadge op posters"
                    )
                    categoryCard(
                        .source, icon: "server.rack", title: "Metadatabron",
                        subtitle: "Poster, achtergrond en omschrijving"
                    )
                    categoryCard(
                        .ratings, icon: "star.leadinghalf.filled", title: "Ratings",
                        subtitle: "Zichtbare beoordelingen op detailpagina's"
                    )
                }
                .frame(maxWidth: 1300, alignment: .leading)
                .padding(.horizontal, VeyraSpacing.page)
                .padding(.top, 36)
                .padding(.bottom, 60)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Metadata")
        .navigationDestination(item: $destination) { destination in
            switch destination {
            case .posterEnrichment: PosterEnrichmentSettingsView()
            case .source: MetadataSourceSettingsView()
            case .ratings: MetadataRatingsSettingsView()
            }
        }
    }

    private func categoryCard(
        _ target: MetadataSettingsDestination,
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

private enum MetadataSettingsDestination: String, Identifiable, Hashable {
    case posterEnrichment, source, ratings

    var id: String { rawValue }
}

// MARK: - Posterverrijking

private struct PosterEnrichmentSettingsView: View {
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
                // Blijft een systeem-Picker met .menu (niet de nieuwe
                // verticale VeyraSettingsChoiceRow): deze rij wordt direct
                // gevolgd door secties die in-/uitklappen zodra de keuze
                // verandert (voorbeeldposter, toggles). Met een push-stijl
                // (NavigationLink) duwt tvOS een apart kiesscherm open en
                // moet het bij het teruggaan tegelijk de lijst herbouwen
                // — die combinatie liet de focus-engine soms vastlopen
                // (de app viel dan terug naar het beginscherm). Een
                // menu-stijl kiezer verandert de selectie zonder te
                // navigeren, dus die botsing kan niet meer optreden.
                Picker("Bron", selection: $posterEnrichmentSourceRaw) {
                    ForEach(PosterEnrichmentMode.allCases) { option in
                        Text(option.title).tag(option.rawValue)
                    }
                }
                .pickerStyle(.menu)

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
                        // Zelfde reden als "Bron" hierboven: .menu i.p.v.
                        // push-stijl, om de focus-engine niet te laten
                        // vastlopen in een sectie die zelf ook in-/uitklapt.
                        Picker("Bron beoordeling", selection: $posterRatingSourceRaw) {
                            ForEach(PosterRatingSource.allCases) { option in
                                Text(option.title).tag(option.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    Toggle("Leeftijdsclassificatie", isOn: $posterShowAgeRating)
                    Toggle("Kwaliteitslabels", isOn: $posterShowQuality)
                    Toggle("Trendlabels", isOn: $posterShowTrending)
                    Toggle("Resterende afleveringen", isOn: $posterShowEpisodesRemaining)
                } else if posterEnrichmentSource == .rpdb {
                    Text("RPDB (ratingposterdb.com) is een externe dienst waarvoor nog geen integratie bestaat — deze keuze doet nog niets. Kies Better Posters voor werkende genre-/beoordelingslabels.")
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("Toont een badge met genre en/of beoordeling op de posters in Films, Series en het startscherm. Genre en Beoordeling via Better Posters werken al echt; Leeftijdsclassificatie, Kwaliteitslabels, Trendlabels en Resterende afleveringen staan klaar maar Veyra haalt die gegevens nog niet op.")
            }
        }
        .frame(maxWidth: 1000)
        .navigationTitle("Posterverrijking")
    }
}

// MARK: - Metadatabron

private struct MetadataSourceSettingsView: View {
    @AppStorage("metadata.source.preference")
    private var metadataSourceRaw = MetadataSourceOption.tmdb.rawValue

    var body: some View {
        Form {
            Section {
                VeyraSettingsChoiceRow<MetadataSourceOption>("Metadatabron", selection: $metadataSourceRaw)
            } footer: {
                Text("Bepaalt waar poster, achtergrond en omschrijving vandaan komen voor titels zonder eigen afbeeldingen (bv. Trakt-lijsten). AIOMetadata vereist een addon bij Addons.")
            }
        }
        .frame(maxWidth: 1000)
        .navigationTitle("Metadatabron")
    }
}

// MARK: - Ratings

private struct MetadataRatingsSettingsView: View {
    @AppStorage("metadata.rating.imdb") private var imdb = true
    @AppStorage("metadata.rating.tmdb") private var tmdb = true
    @AppStorage("metadata.rating.tomatometer") private var tomatometer = true
    @AppStorage("metadata.rating.metacritic") private var metacritic = true
    @AppStorage("metadata.rating.trakt") private var trakt = true
    @AppStorage("metadata.rating.popcornmeter") private var popcornmeter = true

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $imdb) { providerRow(.imdb) }
                Toggle(isOn: $tmdb) { providerRow(.tmdb) }
                Toggle(isOn: $tomatometer) { providerRow(.tomatometer) }
                Toggle(isOn: $metacritic) { providerRow(.metacritic) }
                Toggle(isOn: $trakt) { providerRow(.trakt) }
                Toggle(isOn: $popcornmeter) { providerRow(.popcornmeter) }
            } footer: {
                Text("Kies welke ratings zichtbaar zijn op film- en seriepagina's.")
            }

            Section {
                Button("Alle ratings inschakelen") { enableAll() }
                Button("Alle ratings uitschakelen") { disableAll() }
                Button("Standaardinstellingen herstellen") { resetDefaults() }
            }
        }
        .frame(maxWidth: 1000)
        .navigationTitle("Ratings")
    }

    // MARK: - Provider Row

    @ViewBuilder
    private func providerRow(_ provider: MetadataRatingProvider) -> some View {
        HStack(spacing: 16) {
            providerIcon(provider)

            Text(provider.title)
                .font(.system(size: 22, weight: .medium, design: .rounded))
        }
    }

    // MARK: - Provider Icon

    @ViewBuilder
    private func providerIcon(_ provider: MetadataRatingProvider) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(iconBackground(provider))
                .frame(width: 44, height: 44)

            Image(systemName: provider.systemImage)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(iconForeground(provider))
        }
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
