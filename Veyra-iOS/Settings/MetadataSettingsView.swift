import SwiftUI

struct MetadataSettingsView: View {
    @AppStorage("metadata.source.preference") private var metadataSourceRaw = MetadataSourceOption.tmdb.rawValue

    // §74: enkel een compacte status als die betrouwbaar vast te stellen is.
    @State private var connectivity: AddonConnectivityStatus?

    // Fase 3 stap 4 (artwork-engine-spec §38/§39): geen los `@AppStorage`-paar, want
    // `ArtworkSettings` is één samengesteld, versioned record (net als `RegionalReleaseSettings`)
    // i.p.v. drie losse sleutels.
    @State private var artworkSettings = ArtworkSettingsStore().load()
    private let artworkStore = ArtworkSettingsStore()

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

    @AppStorage(MetadataRatingProvider.imdb.storageKey) private var imdb = true
    @AppStorage(MetadataRatingProvider.tmdb.storageKey) private var tmdb = true
    @AppStorage(MetadataRatingProvider.tomatometer.storageKey) private var tomatometer = true
    @AppStorage(MetadataRatingProvider.metacritic.storageKey) private var metacritic = true
    @AppStorage(MetadataRatingProvider.trakt.storageKey) private var trakt = true
    @AppStorage(MetadataRatingProvider.popcornmeter.storageKey) private var popcornmeter = true
    @AppStorage(MetadataRatingProvider.letterboxd.storageKey) private var letterboxd = true
    @AppStorage(MetadataRatingProvider.mal.storageKey) private var mal = true

    var body: some View {
        VeyraDynamicBackgroundScope {
            ZStack {
                VeyraBackground().ignoresSafeArea()

                VeyraList {
                    Section {
                        Picker("Posterverrijking", selection: $posterEnrichmentSourceRaw) {
                            ForEach(PosterEnrichmentMode.allCases) { option in
                                Text(option.title).tag(option.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)

                        if posterEnrichmentSource == .betterPosters {
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
                                .disabled(true)
                            Toggle("Trendlabels", isOn: $posterShowTrending)
                        }
                    } header: {
                        Text("Posterverrijking")
                    } footer: {
                        Text("Toont een badge op de posters in Films, Series en het startscherm. Genre, Beoordeling, Leeftijdsclassificatie en Trendlabels werken allemaal echt. Kwaliteitslabels staat uitgeschakeld: dat vraagt per titel een opgezochte stream, wat voor een heel posterrooster te veel netwerkverkeer zou zijn.")
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
                        Text("Bepaalt waar poster, achtergrond en omschrijving vandaan komen voor titels zonder eigen afbeeldingen (bv. Trakt-lijsten). AIOMetadata gebruikt de addonconfiguratie via VeyraHub.")
                    }

                    if let addon = MetadataSourcePreference.activeAddon() {
                        Section {
                            AddonConnectivityRow(addon: addon, status: connectivity)
                        } header: {
                            Text("Status")
                        }
                    }

                    Section {
                        NavigationLink {
                            MetadataDiagnosticsView()
                        } label: {
                            Label("Diagnostics", systemImage: "stethoscope")
                        }
                    } footer: {
                        Text("Metadata-/artworkbron, cache, fallback en duur van de laatste aanvragen deze sessie.")
                    }

                    Section {
                        Picker("Titelweergave", selection: artworkBinding(\.titleDisplay)) {
                            ForEach(ArtworkTitleDisplayMode.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                        Picker("Taalvoorkeur", selection: artworkBinding(\.language)) {
                            ForEach(ArtworkLanguageOption.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                        Picker("Fallbacktaal", selection: artworkBinding(\.fallbackLanguage)) {
                            ForEach(ArtworkLanguageOption.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                    } header: {
                        Text("Artwork")
                    } footer: {
                        Text("Bepaalt of Detail/Hero/Player een ClearLogo tonen i.p.v. titeltekst, en in welke taal. Geldt voor zowel TMDB als een gekozen AIOMetadata-addon.")
                    }

                    Section {
                        toggleRow(.imdb, isOn: $imdb)
                        toggleRow(.tmdb, isOn: $tmdb)
                        toggleRow(.tomatometer, isOn: $tomatometer)
                        toggleRow(.metacritic, isOn: $metacritic)
                        toggleRow(.trakt, isOn: $trakt)
                        toggleRow(.popcornmeter, isOn: $popcornmeter)
                        toggleRow(.letterboxd, isOn: $letterboxd)
                        toggleRow(.mal, isOn: $mal)
                    } header: {
                        Text("Ratings")
                    } footer: {
                        Text("Kies welke ratings zichtbaar zijn op film- en seriepagina's. Een titel toont alleen de scores die de bron er daadwerkelijk voor heeft. Popcornmeter en Letterboxd tonen enkel iets wanneer je bij Account een MDBList API-sleutel hebt ingesteld.")
                    }

                    Section {
                        Button("Alle ratings inschakelen") { setAll(true) }
                        Button("Alle ratings uitschakelen") { setAll(false) }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Metadata")
            .task(id: metadataSourceRaw) { await checkConnectivity() }

        }
    }

    private func checkConnectivity() async {
        guard let addon = MetadataSourcePreference.activeAddon() else {
            connectivity = nil
            return
        }
        connectivity = .checking
        connectivity = await AddonConnectivityChecker.check(addon)
    }

    // MARK: - Artwork

    private func artworkBinding<Value>(_ keyPath: WritableKeyPath<ArtworkSettings, Value>) -> Binding<Value> {
        Binding(
            get: { artworkSettings[keyPath: keyPath] },
            set: { newValue in
                artworkSettings[keyPath: keyPath] = newValue
                artworkStore.save(artworkSettings)
            }
        )
    }

    // MARK: - Row

    private func toggleRow(_ provider: MetadataRatingProvider, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(iconBackground(provider))
                        .frame(width: 36, height: 36)

                    if let assetName = provider.assetImageName {
                        Image(assetName)
                            .renderingMode(.original)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 34, height: 34)
                    } else {
                        Image(systemName: provider.systemImage)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(iconForeground(provider))
                    }
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

    private func setAll(_ enabled: Bool) {
        imdb = enabled
        tmdb = enabled
        tomatometer = enabled
        metacritic = enabled
        trakt = enabled
        popcornmeter = enabled
        letterboxd = enabled
        mal = enabled
    }
}

struct MDBListConfigurationCard: View {
    @State
    private var apiKey = ""

    @State
    private var configured = false

    @State
    private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "star.leadinghalf.filled")
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("MDBList")
                    Text("Popcornmeter- en Letterboxd-scores")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(configured ? "Actief" : "API-sleutel nodig")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(configured ? VeyraColors.cyan : .orange)
            }

            Text("Veyra zoekt hiermee de Popcornmeter- en Letterboxd-score op via de IMDb-identificatie van een film of serie. MDBList biedt een gratis API-sleutel aan op mdblist.com.")
                .font(.caption)
                .foregroundStyle(.secondary)

            SecureField(
                configured ? "Nieuwe MDBList API-sleutel" : "MDBList API-sleutel",
                text: $apiKey
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textFieldStyle(.roundedBorder)

            Button("Opslaan") {
                saveAPIKey()
            }
            .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(configured ? VeyraColors.cyan : .orange)
            }
        }
        .padding(.vertical, 4)
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

#Preview {
    NavigationStack { MetadataSettingsView() }
}
