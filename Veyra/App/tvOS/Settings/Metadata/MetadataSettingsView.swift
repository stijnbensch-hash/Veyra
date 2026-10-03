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
                        .artwork, icon: "textformat", title: "Artwork",
                        subtitle: "ClearLogo en titelweergave"
                    )
                    categoryCard(
                        .ratings, icon: "star.leadinghalf.filled", title: "Ratings",
                        subtitle: "Zichtbare beoordelingen op detailpagina's"
                    )
                    categoryCard(
                        .diagnostics, icon: "stethoscope", title: "Diagnostics",
                        subtitle: "Metadata-/artworkbron, cache, fallback, duur"
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
            case .artwork: ArtworkSettingsSettingsView()
            case .ratings: MetadataRatingsSettingsView()
            case .diagnostics: MetadataDiagnosticsView()
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
    case posterEnrichment, source, artwork, ratings, diagnostics

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
                .pickerStyle(.menu)

                if posterEnrichmentSource == .betterPosters {
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

                    VeyraSettingsToggleRow(icon: "tag", title: "Genre", isOn: $posterShowGenre)
                    VeyraSettingsToggleRow(icon: "star", title: "Beoordeling", isOn: $posterShowRating)
                    if posterShowRating {
                        Picker("Bron beoordeling", selection: $posterRatingSourceRaw) {
                            ForEach(PosterRatingSource.allCases) { option in
                                Text(option.title).tag(option.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    VeyraSettingsToggleRow(icon: "checkmark.seal", title: "Leeftijdsclassificatie", isOn: $posterShowAgeRating)
                    VeyraSettingsToggleRow(icon: "rosette", title: "Kwaliteitslabels", isOn: $posterShowQuality)
                        .disabled(true)
                    VeyraSettingsToggleRow(icon: "chart.line.uptrend.xyaxis", title: "Trendlabels", isOn: $posterShowTrending)
                }
            } footer: {
                Text("Toont een badge op de posters in Films, Series en het startscherm. Genre, Beoordeling, Leeftijdsclassificatie en Trendlabels werken allemaal echt. Kwaliteitslabels staat uitgeschakeld: dat vraagt per titel een opgezochte stream, wat voor een heel posterrooster te veel netwerkverkeer zou zijn.")
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

    // §74: enkel een compacte status als die betrouwbaar vast te stellen is -- geen addon
    // geconfigureerd betekent hier gewoon "geen status", geen gok.
    @State private var connectivity: AddonConnectivityStatus?

    var body: some View {
        Form {
            Section {
                VeyraSettingsChoiceRow<MetadataSourceOption>(icon: "text.book.closed", "Metadatabron", selection: $metadataSourceRaw)
            } footer: {
                Text("Bepaalt waar poster, achtergrond en omschrijving vandaan komen voor titels zonder eigen afbeeldingen (bv. Trakt-lijsten). AIOMetadata gebruikt de addonconfiguratie via VeyraHub.")
            }

            if let addon = MetadataSourcePreference.activeAddon() {
                Section {
                    AddonConnectivityRow(addon: addon, status: connectivity)
                } header: {
                    Text("Status")
                }
            }
        }
        .frame(maxWidth: 1000)
        .navigationTitle("Metadatabron")
        .task(id: metadataSourceRaw) { await checkConnectivity() }
    }

    private func checkConnectivity() async {
        guard let addon = MetadataSourcePreference.activeAddon() else {
            connectivity = nil
            return
        }
        connectivity = .checking
        connectivity = await AddonConnectivityChecker.check(addon)
    }
}

// MARK: - Artwork (Fase 3 stap 4, artwork-engine-spec §38/§39)

private struct ArtworkSettingsSettingsView: View {
    @State private var settings = ArtworkSettingsStore().load()
    private let store = ArtworkSettingsStore()

    var body: some View {
        Form {
            Section {
                VeyraSettingsChoiceRow<ArtworkTitleDisplayMode>(icon: "textformat", "Titelweergave", selection: titleDisplayBinding)
                VeyraSettingsChoiceRow<ArtworkLanguageOption>(icon: "globe", "Taalvoorkeur", selection: languageBinding)
                VeyraSettingsChoiceRow<ArtworkLanguageOption>(icon: "globe", "Fallbacktaal", selection: fallbackLanguageBinding)
            } footer: {
                Text("Bepaalt of Detail/Hero/Player een ClearLogo tonen i.p.v. titeltekst, en in welke taal. Geldt voor zowel TMDB als een gekozen AIOMetadata-addon.")
            }
        }
        .frame(maxWidth: 1000)
        .navigationTitle("Artwork")
    }

    private var titleDisplayBinding: Binding<String> {
        Binding(
            get: { settings.titleDisplay.rawValue },
            set: { raw in
                guard let value = ArtworkTitleDisplayMode(rawValue: raw) else { return }
                settings.titleDisplay = value
                store.save(settings)
            }
        )
    }

    private var languageBinding: Binding<String> {
        Binding(
            get: { settings.language.rawValue },
            set: { raw in
                guard let value = ArtworkLanguageOption(rawValue: raw) else { return }
                settings.language = value
                store.save(settings)
            }
        )
    }

    private var fallbackLanguageBinding: Binding<String> {
        Binding(
            get: { settings.fallbackLanguage.rawValue },
            set: { raw in
                guard let value = ArtworkLanguageOption(rawValue: raw) else { return }
                settings.fallbackLanguage = value
                store.save(settings)
            }
        )
    }
}

extension ArtworkTitleDisplayMode: VeyraSettingsOption {}
extension ArtworkLanguageOption: VeyraSettingsOption {}

// MARK: - Ratings

private struct MetadataRatingsSettingsView: View {
    @AppStorage("metadata.rating.imdb") private var imdb = true
    @AppStorage("metadata.rating.tmdb") private var tmdb = true
    @AppStorage("metadata.rating.tomatometer") private var tomatometer = true
    @AppStorage("metadata.rating.metacritic") private var metacritic = true
    @AppStorage("metadata.rating.trakt") private var trakt = true
    @AppStorage("metadata.rating.popcornmeter") private var popcornmeter = true
    @AppStorage("metadata.rating.letterboxd") private var letterboxd = true
    @AppStorage("metadata.rating.mal") private var mal = true

    var body: some View {
        Form {
            Section {
                ratingToggleRow(providerRow(.imdb), isOn: $imdb)
                ratingToggleRow(providerRow(.tmdb), isOn: $tmdb)
                ratingToggleRow(providerRow(.tomatometer), isOn: $tomatometer)
                ratingToggleRow(providerRow(.metacritic), isOn: $metacritic)
                ratingToggleRow(providerRow(.trakt), isOn: $trakt)
                ratingToggleRow(providerRow(.popcornmeter), isOn: $popcornmeter)
                ratingToggleRow(providerRow(.letterboxd), isOn: $letterboxd)
                ratingToggleRow(providerRow(.mal), isOn: $mal)
            } footer: {
                Text("Kies welke ratings zichtbaar zijn op film- en seriepagina's. Popcornmeter en Letterboxd tonen enkel iets wanneer je bij Account een MDBList API-sleutel hebt ingesteld.")
            }

            Section {
                Button {
                    enableAll()
                } label: {
                    VeyraSettingsCardRowLabel(icon: "checkmark.circle", title: "Alle ratings inschakelen")
                }
                .veyraCardRow()

                Button {
                    disableAll()
                } label: {
                    VeyraSettingsCardRowLabel(icon: "xmark.circle", title: "Alle ratings uitschakelen")
                }
                .veyraCardRow()

                Button {
                    resetDefaults()
                } label: {
                    VeyraSettingsCardRowLabel(icon: "arrow.counterclockwise", title: "Standaardinstellingen herstellen")
                }
                .veyraCardRow()
            }
        }
        .frame(maxWidth: 1000)
        .navigationTitle("Ratings")
    }

    // MARK: - Provider Row

    /// Rijversie van een rating-toggle: eigen kleuren-icoon van
    /// `providerRow(_:)` + een eigen aan/uit-indicator i.p.v. een systeem-
    /// `Toggle` (die legt op tvOS binnen een List zijn eigen felwitte
    /// focus-highlight over de hele rij, zie `VeyraSettingsCardRow.swift`).
    private func ratingToggleRow<Label: View>(_ label: Label, isOn: Binding<Bool>, disabled: Bool = false) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 16) {
                label
                Spacer()
                VeyraSettingsCardRowSwitch(isOn: isOn.wrappedValue)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .opacity(disabled ? 0.5 : 1)
        }
        .veyraCardRow()
        .disabled(disabled)
    }

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

            if let assetName = provider.assetImageName {
                Image(assetName)
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
            } else {
                Image(systemName: provider.systemImage)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(iconForeground(provider))
            }
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
        case .letterboxd: return .green.opacity(0.22)
        case .mal: return .blue.opacity(0.22)
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
        case .letterboxd: return .green
        case .mal: return .blue
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
        letterboxd = true
        mal = true
    }

    private func disableAll() {
        imdb = false
        tmdb = false
        tomatometer = false
        metacritic = false
        trakt = false
        popcornmeter = false
        letterboxd = false
        mal = false
    }

    private func resetDefaults() {
        enableAll()
    }
}

// MARK: - MDBList Configuration Card

struct MDBListConfigurationCard: View {
    @State
    private var apiKey = ""

    @State
    private var configured = false

    @State
    private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(systemName: "star.leadinghalf.filled")
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 3) {
                    Text("MDBList")
                    Text("Popcornmeter- en Letterboxd-scores")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VeyraPosterBadge(
                    title: configured ? "Actief" : "API-sleutel nodig",
                    symbol: configured ? "checkmark.circle.fill" : "key.fill",
                    accent: configured ? VeyraColors.cyan : VeyraColors.red,
                    fontSize: 13
                )
            }

            Text("Veyra zoekt hiermee de Popcornmeter- en Letterboxd-score op via de IMDb-identificatie van een film of serie. MDBList biedt een gratis API-sleutel aan op mdblist.com.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("De API-sleutel wordt lokaal in de beveiligde sleutelhanger van deze Apple TV opgeslagen.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.52))

            SecureField(
                configured
                    ? "Nieuwe MDBList API-sleutel"
                    : "MDBList API-sleutel",
                text: $apiKey
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            Button {
                saveAPIKey()
            } label: {
                Label("Opslaan", systemImage: "key.fill")
            }
            .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(configured ? VeyraColors.ice : .orange)
            }
        }
        .onAppear {
            configured = AppConfiguration.mdblistAPIKey?.isEmpty == false
        }
    }

    private func saveAPIKey() {
        let value = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }

        do {
            try AppConfiguration.setMDBListAPIKey(value)
            apiKey = ""
            configured = AppConfiguration.mdblistAPIKey?.isEmpty == false
            message = configured
                ? "API-sleutel veilig opgeslagen. Popcornmeter en Letterboxd zijn actief."
                : "De API-sleutel kon niet worden opgeslagen."
        } catch {
            configured = AppConfiguration.mdblistAPIKey?.isEmpty == false
            message = "Opslaan van de API-sleutel is niet gelukt."
        }
    }
}

// MARK: - TheIntroDB Configuration Card

struct IntroDBConfigurationCard: View {
    @State
    private var apiKey = ""

    @State
    private var configured = false

    @State
    private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(systemName: "forward.end.fill")
                    .foregroundStyle(VeyraColors.cyan)

                VStack(alignment: .leading, spacing: 3) {
                    Text("TheIntroDB")
                    Text("Intro, samenvatting en aftiteling overslaan")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VeyraPosterBadge(
                    title: configured ? "Actief" : "Optioneel",
                    symbol: configured ? "checkmark.circle.fill" : "key.fill",
                    accent: configured ? VeyraColors.cyan : VeyraColors.ice,
                    fontSize: 13
                )
            }

            Text("Haalt exacte start-/eindtijden op bij theintrodb.org om intro's, samenvattingen en aftitelingen over te slaan tijdens afspelen. Werkt ook zonder sleutel (lager limiet); een gratis sleutel geeft voorrang en een hoger limiet.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("De API-sleutel wordt lokaal in de beveiligde sleutelhanger van deze Apple TV opgeslagen.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.52))

            SecureField(
                configured
                    ? "Nieuwe TheIntroDB API-sleutel"
                    : "TheIntroDB API-sleutel",
                text: $apiKey
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            Button {
                saveAPIKey()
            } label: {
                Label("Opslaan", systemImage: "key.fill")
            }
            .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(configured ? VeyraColors.ice : .orange)
            }
        }
        .onAppear {
            configured = AppConfiguration.introDBAPIKey?.isEmpty == false
        }
    }

    private func saveAPIKey() {
        let value = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }

        do {
            try AppConfiguration.setIntroDBAPIKey(value)
            apiKey = ""
            configured = AppConfiguration.introDBAPIKey?.isEmpty == false
            message = configured
                ? "API-sleutel veilig opgeslagen."
                : "De API-sleutel kon niet worden opgeslagen."
        } catch {
            configured = AppConfiguration.introDBAPIKey?.isEmpty == false
            message = "Opslaan van de API-sleutel is niet gelukt."
        }
    }
}

#Preview {
    NavigationStack {
        MetadataSettingsView()
    }
}
