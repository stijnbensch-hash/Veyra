import SwiftUI

private enum ShelfSourceKind: String, CaseIterable, Hashable {
    case trakt
    case tmdb
    case addon
    case iptv
}

private enum TMDBListSourceMode: String, CaseIterable, Hashable {
    case standard
    case personal
}

struct ShelfEditView: View {
    @Environment(\.dismiss) private var dismiss

    let shelf: Shelf?
    let viewModel: ShelvesViewModel

    @State private var kind: ShelfMediaKind = .movie
    @State private var sourceKind: ShelfSourceKind = .trakt
    @State private var traktList: TraktShelfList = .trending
    @State private var traktPersonalLists: [TraktPersonalList] = []
    @State private var isLoadingTraktPersonalLists = false
    @State private var tmdbList: TMDBShelfList = .popular
    @State private var tmdbListSourceMode: TMDBListSourceMode = .standard
    @State private var tmdbPersonalListIDInput = ""
    @State private var tmdbPersonalListName: String?
    @State private var isFetchingTMDBPersonalList = false
    @State private var tmdbPersonalListError: String?
    @State private var selectedAddonID: UUID?
    @State private var selectedCatalog: AIOMetadataCatalog?
    @State private var availableCatalogs: [AIOMetadataCatalog] = []
    @State private var isLoadingCatalogs = false
    @State private var iptvChannels: [ShelfIPTVChannel] = []
    @State private var title = ""
    @State private var titleEdited = false
    @State private var isEnabled = true
    @State private var errorMessage: String?

    private var metadataAddons: [AddonManifest] {
        AddonStore().load().filter { $0.kind == .aioMetadata }
    }

    var body: some View {
        Form {
            Section {
                VeyraSettingsChoiceRow<ShelfMediaKind>(icon: "square.stack.3d.up", "Soort", selection: Binding(
                    get: { kind.rawValue },
                    set: { kind = ShelfMediaKind(rawValue: $0) ?? .movie }
                ))

                // .segmented: deze rij wordt direct gevolgd door een switch
                // die op basis van sourceKind hele secties in-/uitklapt. Zie
                // de zelfde fix + toelichting in MetadataSettingsView.swift.
                Picker("Bron", selection: $sourceKind) {
                    Text("Trakt").tag(ShelfSourceKind.trakt)
                    Text("TMDB").tag(ShelfSourceKind.tmdb)
                    Text("Addon").tag(ShelfSourceKind.addon)
                    Text("IPTV").tag(ShelfSourceKind.iptv)
                }
                .pickerStyle(.segmented)
            }

            switch sourceKind {
            case .trakt:
                traktSourceSection
            case .tmdb:
                tmdbSourceSection
            case .addon:
                addonSourceSection
            case .iptv:
                iptvSourceSection
            }

            Section("Titel") {
                VeyraSettingsCardRowLabel(icon: "textformat", title: "Titel") {
                    TextField("Titel", text: $title)
                        .multilineTextAlignment(.trailing)
                }
                .onChange(of: title) { _, _ in titleEdited = true }
            }

            Section {
                VeyraSettingsToggleRow(icon: "power", title: "Ingeschakeld", isOn: $isEnabled)
            }

            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(.orange) }
            }

            if shelf != nil {
                Section {
                    Button(role: .destructive) {
                        if let shelf { viewModel.remove(shelf) }
                        dismiss()
                    } label: {
                        VeyraSettingsCardRowLabel(icon: "trash", title: "Plank verwijderen")
                    }
                    .veyraCardRow()
                }
            }
        }
        .frame(maxWidth: 1000)
        .navigationTitle(shelf == nil ? "Plank toevoegen" : "Plank bewerken")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Annuleren") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Opslaan") { save() } }
        }
        .onAppear { setupFromExisting() }
        .onChange(of: kind) { _, _ in updateDefaultTitleIfNeeded() }
        .onChange(of: sourceKind) { _, newValue in
            handleSourceKindChange(newValue)
        }
        .onChange(of: traktList) { _, _ in updateDefaultTitleIfNeeded() }
        .onChange(of: tmdbList) { _, _ in updateDefaultTitleIfNeeded() }
        .onChange(of: tmdbListSourceMode) { _, newValue in
            tmdbPersonalListError = nil
            if newValue == .standard { tmdbPersonalListName = nil }
        }
        .onChange(of: selectedAddonID) { _, _ in Task { await loadCatalogs() } }
        .onChange(of: selectedCatalog) { _, _ in updateDefaultTitleIfNeeded() }
    }

    // MARK: - Source sections

    @ViewBuilder
    private var traktSourceSection: some View {
        Section("Lijst") {
            Picker("Lijst", selection: $traktList) {
                ForEach(TraktShelfList.availableLists(for: kind), id: \.self) { list in
                    Text(list.label(for: kind)).tag(list)
                }
                if !traktPersonalLists.isEmpty {
                    ForEach(traktPersonalLists, id: \.self) { list in
                        Text(list.name)
                            .tag(TraktShelfList.personal(id: list.ids.trakt, slug: list.ids.slug, name: list.name))
                    }
                }
            }

            if isLoadingTraktPersonalLists {
                ProgressView("Eigen lijsten laden…")
            } else if traktPersonalLists.isEmpty {
                Text("Log in bij Trakt (Instellingen → Account) om je eigen lijsten hier te kunnen kiezen.")
                    .foregroundStyle(.secondary)
            }
        }
        .task { await loadTraktPersonalLists() }
    }

    @ViewBuilder
    private var tmdbSourceSection: some View {
        Section {
            // .segmented: deze rij wordt direct gevolgd door content die
            // in-/uitklapt op basis van tmdbListSourceMode zelf. Zie de
            // zelfde fix + toelichting in MetadataSettingsView.swift.
            Picker("Type lijst", selection: $tmdbListSourceMode) {
                Text("Standaardlijst").tag(TMDBListSourceMode.standard)
                Text("Eigen lijst (ID)").tag(TMDBListSourceMode.personal)
            }
            .pickerStyle(.segmented)

            if tmdbListSourceMode == .standard {
                Picker("Lijst", selection: $tmdbList) {
                    ForEach(TMDBShelfList.availableLists(for: kind), id: \.self) { list in
                        Text(list.label(for: kind)).tag(list)
                    }
                }
            } else {
                VeyraSettingsCardRowLabel(icon: "number", title: "TMDB-lijst-ID") {
                    TextField("bv. 12345", text: $tmdbPersonalListIDInput)
                        .multilineTextAlignment(.trailing)
                }

                Button {
                    Task { await fetchTMDBPersonalList() }
                } label: {
                    VeyraSettingsCardRowLabel(icon: "arrow.down.circle", title: "Lijst ophalen")
                }
                .veyraCardRow()
                .disabled(
                    tmdbPersonalListIDInput.trimmingCharacters(in: .whitespaces).isEmpty
                        || isFetchingTMDBPersonalList
                )

                if isFetchingTMDBPersonalList {
                    ProgressView("Lijst controleren…")
                }
                if let tmdbPersonalListName {
                    Text("Gevonden: \(tmdbPersonalListName)").foregroundStyle(.secondary)
                }
                if let tmdbPersonalListError {
                    Text(tmdbPersonalListError).foregroundStyle(.orange)
                }
            }
        } header: {
            Text("Lijst")
        } footer: {
            if tmdbListSourceMode == .personal {
                Text("Het ID vind je in de URL van je TMDB-lijst, bv. themoviedb.org/list/12345 → 12345. De lijst moet publiek staan.")
            }
        }
    }

    @ViewBuilder
    private var addonSourceSection: some View {
        Section("Addon") {
            if metadataAddons.isEmpty {
                Text("Voeg eerst een AIOMetadata-addon toe bij Addons.")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Addon", selection: $selectedAddonID) {
                    ForEach(metadataAddons) { addon in
                        Text(addon.name).tag(addon.id as UUID?)
                    }
                }

                if isLoadingCatalogs {
                    ProgressView("Catalogi laden…")
                } else if availableCatalogs.isEmpty {
                    Text("Geen catalogi gevonden voor deze addon.")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Catalogus", selection: $selectedCatalog) {
                        ForEach(availableCatalogs, id: \.self) { catalog in
                            Text(catalog.displayName).tag(catalog as AIOMetadataCatalog?)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var iptvSourceSection: some View {
        Section("Zenders") {
            NavigationLink {
                ShelfIPTVChannelPickerView(selectedChannels: $iptvChannels)
            } label: {
                VeyraSettingsCardRowLabel(icon: "tv", title: "Kanalen kiezen") {
                    VeyraSettingsCardRowValue(value: iptvChannels.isEmpty ? "Geen" : "\(iptvChannels.count)")
                }
            }
            .veyraCardRow()

            if iptvChannels.isEmpty {
                Text("Kies zelf welke zenders in deze plank moeten staan — uit één of meerdere providers.")
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: iptvChannels) { _, _ in updateDefaultTitleIfNeeded() }
    }

    // MARK: - Setup

    private func handleSourceKindChange(_ newValue: ShelfSourceKind) {
        if newValue == .addon, selectedAddonID == nil {
            selectedAddonID = metadataAddons.first?.id
        }
        updateDefaultTitleIfNeeded()
    }

    private func setupFromExisting() {
        guard let shelf else {
            title = defaultTitle()
            return
        }

        title = shelf.title
        isEnabled = shelf.isEnabled
        titleEdited = true

        switch shelf.source {
        case .trakt(let list, let mediaKind):
            kind = mediaKind
            sourceKind = .trakt
            traktList = list
        case .tmdb(let list, let mediaKind):
            kind = mediaKind
            sourceKind = .tmdb
            tmdbList = list
            if case .personal(let id, let name) = list {
                tmdbListSourceMode = .personal
                tmdbPersonalListIDInput = String(id)
                tmdbPersonalListName = name
            }
        case .addon(let addonID, _, let catalogType, let catalogID, let catalogName):
            kind = catalogType == "series" ? .series : .movie
            sourceKind = .addon
            selectedAddonID = addonID
            selectedCatalog = AIOMetadataCatalog(type: catalogType, id: catalogID, name: catalogName)
            Task { await loadCatalogs() }
        case .iptv(let channels):
            sourceKind = .iptv
            iptvChannels = channels
        }
    }

    private func defaultTitle() -> String {
        switch sourceKind {
        case .trakt: return traktList.label(for: kind)
        case .tmdb: return tmdbList.label(for: kind)
        case .addon:
            guard let selectedCatalog, let addon = metadataAddons.first(where: { $0.id == selectedAddonID }) else {
                return "Addon-catalogus"
            }
            return "\(addon.name) · \(selectedCatalog.displayName)"
        case .iptv:
            return "Mijn zenders"
        }
    }

    private func updateDefaultTitleIfNeeded() {
        guard !titleEdited else { return }
        title = defaultTitle()
    }

    // MARK: - Persoonlijke lijsten

    private func loadTraktPersonalLists() async {
        guard traktPersonalLists.isEmpty, !isLoadingTraktPersonalLists else { return }
        isLoadingTraktPersonalLists = true
        defer { isLoadingTraktPersonalLists = false }
        traktPersonalLists = await ShelfCatalogService.fetchTraktPersonalLists()
    }

    private func fetchTMDBPersonalList() async {
        guard let id = Int(tmdbPersonalListIDInput.trimmingCharacters(in: .whitespaces)) else {
            tmdbPersonalListError = "Voer een geldig numeriek lijst-ID in."
            return
        }

        isFetchingTMDBPersonalList = true
        tmdbPersonalListError = nil
        defer { isFetchingTMDBPersonalList = false }

        do {
            let result = try await ShelfCatalogService.fetchTMDBPersonalList(id: id)
            tmdbPersonalListName = result.name
            tmdbList = .personal(id: id, name: result.name)
            updateDefaultTitleIfNeeded()
        } catch {
            tmdbPersonalListName = nil
            tmdbPersonalListError = error.localizedDescription
        }
    }

    // MARK: - Addon-catalogi

    private func loadCatalogs() async {
        guard sourceKind == .addon, let addonID = selectedAddonID,
              let addon = metadataAddons.first(where: { $0.id == addonID })
        else {
            availableCatalogs = []
            return
        }

        isLoadingCatalogs = true
        defer { isLoadingCatalogs = false }

        do {
            let manifest = try await AIOMetadataClient(baseURL: addon.baseURL).manifest()
            let catalogs = manifest.catalogs ?? []
            availableCatalogs = catalogs.filter { $0.type == (kind == .movie ? "movie" : "series") }
            if selectedCatalog == nil { selectedCatalog = availableCatalogs.first }
            updateDefaultTitleIfNeeded()
        } catch {
            availableCatalogs = []
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Opslaan

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            errorMessage = "Geef deze plank een titel."
            return
        }

        let source: ShelfSource
        switch sourceKind {
        case .trakt:
            source = .trakt(list: traktList, kind: kind)
        case .tmdb:
            if tmdbListSourceMode == .personal {
                guard case .personal = tmdbList else {
                    errorMessage = "Haal eerst de lijst op via 'Lijst ophalen'."
                    return
                }
            }
            source = .tmdb(list: tmdbList, kind: kind)
        case .addon:
            guard let addonID = selectedAddonID,
                  let addon = metadataAddons.first(where: { $0.id == addonID }),
                  let selectedCatalog
            else {
                errorMessage = "Kies een addon en een catalogus."
                return
            }
            source = .addon(
                addonID: addonID,
                addonName: addon.name,
                catalogType: selectedCatalog.type,
                catalogID: selectedCatalog.id,
                catalogName: selectedCatalog.displayName
            )
        case .iptv:
            guard !iptvChannels.isEmpty else {
                errorMessage = "Kies minstens één zender."
                return
            }
            source = .iptv(channels: iptvChannels)
        }

        if let shelf {
            viewModel.update(Shelf(id: shelf.id, title: trimmedTitle, isEnabled: isEnabled, source: source))
        } else {
            viewModel.add(Shelf(title: trimmedTitle, isEnabled: isEnabled, source: source))
        }
        dismiss()
    }
}
