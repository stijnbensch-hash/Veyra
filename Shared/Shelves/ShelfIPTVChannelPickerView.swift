import SwiftUI

/// Laat de gebruiker losse IPTV-kanalen kiezen voor een plank
/// (`ShelfSource.iptv`), of voor VOD (films/series) hele aanbieder-categorieën
/// (bv. "NETFLIX", "AMAZON PRIME") in één keer — desgewenst uit meerdere
/// providers door dit scherm meerdere keren te openen. Werkt op tvOS en iOS.
///
/// Bij VOD kies je dus niet losse titels, maar een categorie: alle films/
/// series die er op het moment van aanvinken in zitten worden als vaste
/// snapshot aan de plank toegevoegd (zoals bij losse kanalen). Series hebben
/// geen eigen afspeel-URL — die worden op de plank geopend via
/// `ShelfIPTVSeriesEpisodesView`, waar een seizoen/aflevering gekozen wordt.
/// Alleen categorieën die in de IPTV-instellingen ("VOD beheren") niet
/// verborgen zijn, worden getoond.
struct ShelfIPTVChannelPickerView: View {
    @Binding var selectedChannels: [ShelfIPTVChannel]
    @Environment(\.dismiss) private var dismiss

    @State private var providers: [IPTVStoredProvider] = []
    @State private var selectedProviderID: UUID?
    @State private var contentKind: ShelfIPTVItemKind = .live

    // Zenders (per kanaal)
    @State private var groupedLive: [(name: String, items: [PickerItem])] = []

    // VOD (per categorie/"aanbieder")
    @State private var vodCategorySections: [(name: String, rows: [CategoryRow])] = []
    @State private var vodItemsByCategoryID: [String: [PickerItem]] = [:]
    @State private var seriesItemsByCategoryID: [String: [XtreamSeriesItem]] = [:]
    @State private var vodLoaded = false

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var checkedIDs: Set<String> = []
    @State private var searchText = ""

    private let configurationStore = IPTVConfigurationStore()
    private let preferencesStore = IPTVProviderPreferencesStore()
    private let service = IPTVService()

    private var selectedProvider: IPTVStoredProvider? {
        providers.first { $0.id == selectedProviderID }
    }

    /// Kanalen gefilterd op de zoekopdracht — groepen zonder treffers
    /// vallen weg zodat de lijst overzichtelijk blijft bij veel zenders.
    private var filteredLiveGroups: [(name: String, items: [PickerItem])] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return groupedLive }

        return groupedLive.compactMap { group -> (name: String, items: [PickerItem])? in
            let matches = group.items.filter { $0.name.localizedCaseInsensitiveContains(query) }
            return matches.isEmpty ? nil : (name: group.name, items: matches)
        }
    }

    /// Categorieën gefilterd op de zoekopdracht.
    private var filteredCategorySections: [(name: String, rows: [CategoryRow])] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return vodCategorySections }

        return vodCategorySections.compactMap { section -> (name: String, rows: [CategoryRow])? in
            let matches = section.rows.filter { $0.name.localizedCaseInsensitiveContains(query) }
            return matches.isEmpty ? nil : (name: section.name, rows: matches)
        }
    }

    var body: some View {
        List {
            if providers.count > 1 {
                Section("Provider") {
                    // Naam + soort (Xtream/M3U) samen per optie, zodat je bij
                    // meerdere providers meteen ziet welke welke is.
                    Picker("Provider", selection: $selectedProviderID) {
                        ForEach(providers) { provider in
                            Text("\(provider.displayName) · \(provider.kindLabel)")
                                .tag(provider.id as UUID?)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            Section {
                Picker("Soort", selection: $contentKind) {
                    Text("Zenders").tag(ShelfIPTVItemKind.live)
                    Text("VOD").tag(ShelfIPTVItemKind.vod)
                }
                .pickerStyle(.segmented)
            }

            if isLoading {
                ProgressView(contentKind == .live ? "Kanalen laden…" : "Aanbieders laden…")
            } else if let errorMessage {
                Text(errorMessage).foregroundStyle(.secondary)
            } else if providers.isEmpty {
                Text("Stel eerst een IPTV-provider in bij Live TV.")
                    .foregroundStyle(.secondary)
            } else if contentKind == .live {
                liveContent
            } else {
                vodContent
            }
        }
        .searchable(
            text: $searchText,
            prompt: contentKind == .live ? "Zoek een kanaal" : "Zoek een aanbieder"
        )
        .navigationTitle("Kanalen kiezen")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Gereed") {
                    commit()
                    dismiss()
                }
            }
        }
        .task { await loadProviders() }
        .onChange(of: selectedProviderID) { _, _ in
            vodCategorySections = []
            vodLoaded = false
            Task {
                if contentKind == .live {
                    await loadLiveChannels()
                } else {
                    await loadVODCategories()
                }
            }
        }
        .onChange(of: contentKind) { _, newValue in
            guard newValue == .vod, !vodLoaded else { return }
            Task { await loadVODCategories() }
        }
    }

    // MARK: - Zenders

    private var liveContent: some View {
        Group {
            if groupedLive.isEmpty {
                Text("Geen zenders gevonden voor deze provider.")
                    .foregroundStyle(.secondary)
            } else if filteredLiveGroups.isEmpty {
                Text("Geen zenders gevonden voor '\(searchText)'.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(filteredLiveGroups, id: \.name) { group in
                    Section(group.name) {
                        ForEach(group.items) { item in
                            itemRow(item)
                        }
                    }
                }
            }
        }
    }

    struct PickerItem: Identifiable, Hashable {
        let id: String
        let name: String
        let streamURL: URL
        let logoURL: URL?
        let group: String?
    }

    private func itemRow(_ item: PickerItem) -> some View {
        let isChecked = checkedIDs.contains(liveCompositeID(item))

        return Button {
            toggleLive(item)
        } label: {
            HStack(spacing: 14) {
                Text(item.name)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isChecked ? VeyraColors.cyan : Color.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func liveCompositeID(_ item: PickerItem) -> String {
        "\(ShelfIPTVItemKind.live.rawValue):\(selectedProvider?.displayName ?? ""):\(item.id)"
    }

    private func toggleLive(_ item: PickerItem) {
        let key = liveCompositeID(item)
        if checkedIDs.contains(key) {
            checkedIDs.remove(key)
        } else {
            checkedIDs.insert(key)
        }
    }

    // MARK: - VOD (categorieën)

    /// Eén "aanbieder"/categorie (bv. NETFLIX) binnen Films of Series, met
    /// het aantal titels dat er op dit moment in zit.
    struct CategoryRow: Identifiable, Hashable {
        let id: String
        let categoryID: String
        let kind: ShelfIPTVItemKind
        let name: String
        let count: Int
    }

    private var vodContent: some View {
        Group {
            if vodCategorySections.isEmpty {
                Text("Geen VOD-aanbieders gevonden voor deze provider.")
                    .foregroundStyle(.secondary)
            } else if filteredCategorySections.isEmpty {
                Text("Geen aanbieders gevonden voor '\(searchText)'.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(filteredCategorySections, id: \.name) { section in
                    Section(section.name) {
                        ForEach(section.rows) { row in
                            categoryRow(row)
                        }
                    }
                }
            }
        }
    }

    private func categoryRow(_ row: CategoryRow) -> some View {
        let isChecked = checkedIDs.contains(row.id)

        return Button {
            toggleCategory(row)
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(row.name)
                        .foregroundStyle(.primary)

                    Text(row.count == 1 ? "1 titel" : "\(row.count) titels")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isChecked ? VeyraColors.cyan : Color.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggleCategory(_ row: CategoryRow) {
        if checkedIDs.contains(row.id) {
            checkedIDs.remove(row.id)
        } else {
            checkedIDs.insert(row.id)
        }
    }

    // MARK: - Laden

    private func loadProviders() async {
        do {
            providers = try configurationStore.loadProviders()
            selectedProviderID = providers.first?.id

            // Al eerder voor deze plank gekozen kanalen blijven aangevinkt
            // als je dit scherm opnieuw opent (ook voor andere providers).
            // VOD-categorieën worden pas na het laden ervan aangevinkt
            // (zie `syncCheckedCategories`), want daarvoor moeten eerst de
            // categorieën van de huidige provider bekend zijn.
            checkedIDs = Set(
                selectedChannels
                    .filter { ($0.kind ?? .live) == .live }
                    .map(\.id)
            )

            await loadLiveChannels()
        } catch {
            errorMessage = "IPTV-providers konden niet worden geladen."
        }
    }

    private func loadLiveChannels() async {
        guard let selectedProvider else {
            groupedLive = []
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let channels: [IPTVChannel]
            // Bij Xtream is `channel.group` het ruwe categorie-ID (bv. "10"),
            // geen naam — daarom hier ook de categorieën ophalen en op ID
            // naar hun echte naam vertalen, net als in de Live TV-instellingen
            // (`IPTVLiveVisibilityView`). Bij M3U is de group al de echte naam.
            var categoryNamesByID: [String: String] = [:]

            switch selectedProvider.configuration {
            case .xtream(let xtream):
                async let liveChannels = service.loadXtreamLiveChannels(configuration: xtream)
                async let liveCategories = service.loadXtreamLiveCategories(configuration: xtream)
                let (loadedChannels, categories) = try await (liveChannels, liveCategories)
                channels = loadedChannels
                categoryNamesByID = Dictionary(
                    categories.map { ($0.id, $0.name) },
                    uniquingKeysWith: { first, _ in first }
                )
            case .m3u(let m3u):
                channels = try await service.loadM3UChannels(configuration: m3u)
                    .filter { $0.contentType == .live }
            }

            let grouped = Dictionary(grouping: channels) { channel -> String in
                let rawGroup = channel.group?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !rawGroup.isEmpty else { return "Overige kanalen" }
                return categoryNamesByID[rawGroup] ?? rawGroup
            }
            groupedLive = grouped
                .map { (name: $0.key, items: $0.value.map { channel in
                    PickerItem(
                        id: channel.id,
                        name: ChannelNameOverrideStore.effectiveName(channelID: channel.id, defaultName: channel.name),
                        streamURL: channel.streamURL,
                        logoURL: channel.logoURL,
                        group: channel.group
                    )
                }) }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            errorMessage = "Kanalen konden niet worden geladen: \(error.localizedDescription)"
            groupedLive = []
        }
    }

    private func loadVODCategories() async {
        guard let selectedProvider else {
            vodCategorySections = []
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let preferences = preferencesStore.load(for: selectedProvider.configuration)
        var sections: [(name: String, rows: [CategoryRow])] = []
        let providerName = selectedProvider.displayName

        switch selectedProvider.configuration {
        case .xtream(let xtream):
            do {
                async let vodItemsTask = service.loadXtreamVOD(configuration: xtream)
                async let vodCategoriesTask = service.loadXtreamVODCategories(configuration: xtream)
                async let seriesItemsTask = service.loadXtreamSeries(configuration: xtream)
                async let seriesCategoriesTask = service.loadXtreamSeriesCategories(configuration: xtream)

                let (vodItems, vodCategories, seriesItems, seriesCategories) =
                    try await (vodItemsTask, vodCategoriesTask, seriesItemsTask, seriesCategoriesTask)

                var filmsByCategory: [String: [PickerItem]] = [:]
                for item in vodItems {
                    guard let categoryID = item.categoryID else { continue }
                    filmsByCategory[categoryID, default: []].append(
                        PickerItem(
                            id: item.id,
                            name: item.name,
                            streamURL: item.streamURL,
                            logoURL: item.posterURL,
                            group: categoryID
                        )
                    )
                }
                vodItemsByCategoryID = filmsByCategory

                let filmRows: [CategoryRow] = vodCategories
                    .filter { preferences.isVODCategoryVisible($0.id) }
                    .compactMap { category in
                        guard let count = filmsByCategory[category.id]?.count, count > 0 else { return nil }
                        return CategoryRow(
                            id: "vod:\(providerName):\(category.id)",
                            categoryID: category.id,
                            kind: .vod,
                            name: category.name,
                            count: count
                        )
                    }
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

                var seriesByCategory: [String: [XtreamSeriesItem]] = [:]
                for item in seriesItems {
                    guard let categoryID = item.categoryID else { continue }
                    seriesByCategory[categoryID, default: []].append(item)
                }
                seriesItemsByCategoryID = seriesByCategory

                let seriesRows: [CategoryRow] = seriesCategories
                    .filter { preferences.isSeriesCategoryVisible($0.id) }
                    .compactMap { category in
                        guard let count = seriesByCategory[category.id]?.count, count > 0 else { return nil }
                        return CategoryRow(
                            id: "series:\(providerName):\(category.id)",
                            categoryID: category.id,
                            kind: .series,
                            name: category.name,
                            count: count
                        )
                    }
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

                if !filmRows.isEmpty { sections.append((name: "Films", rows: filmRows)) }
                if !seriesRows.isEmpty { sections.append((name: "Series", rows: seriesRows)) }
            } catch {
                errorMessage = "VOD kon niet worden geladen: \(error.localizedDescription)"
                vodCategorySections = []
                return
            }

        case .m3u(let m3u):
            do {
                let channels = try await service.loadM3UChannels(configuration: m3u)
                    .filter { $0.contentType == .vod }

                var itemsByGroup: [String: [PickerItem]] = [:]
                for channel in channels {
                    let rawGroup = channel.group?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let key = rawGroup.isEmpty ? "Overige" : rawGroup
                    itemsByGroup[key, default: []].append(
                        PickerItem(
                            id: channel.id,
                            name: channel.name,
                            streamURL: channel.streamURL,
                            logoURL: channel.logoURL,
                            group: key
                        )
                    )
                }
                vodItemsByCategoryID = itemsByGroup
                seriesItemsByCategoryID = [:]

                let filmRows: [CategoryRow] = itemsByGroup
                    .filter { preferences.isVODCategoryVisible($0.key) }
                    .map { entry in
                        CategoryRow(
                            id: "vod:\(providerName):\(entry.key)",
                            categoryID: entry.key,
                            kind: .vod,
                            name: entry.key,
                            count: entry.value.count
                        )
                    }
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

                if !filmRows.isEmpty { sections.append((name: "Films", rows: filmRows)) }
            } catch {
                errorMessage = "VOD kon niet worden geladen: \(error.localizedDescription)"
                vodCategorySections = []
                return
            }
        }

        vodCategorySections = sections
        syncCheckedCategories()
        vodLoaded = true
    }

    /// Vinkt categorieën aan waarvan er al items van deze provider op de
    /// plank staan (bv. na eerder aanvinken, of bij het opnieuw openen van
    /// dit scherm).
    private func syncCheckedCategories() {
        guard let selectedProvider else { return }
        let providerName = selectedProvider.displayName

        let selectedCategoryIDs: Set<String> = Set(
            selectedChannels
                .filter { $0.providerName == providerName && ($0.kind == .vod || $0.kind == .series) }
                .compactMap { channel -> String? in
                    guard let group = channel.group, let kind = channel.kind else { return nil }
                    return "\(kind.rawValue):\(providerName):\(group)"
                }
        )

        for section in vodCategorySections {
            for row in section.rows where selectedCategoryIDs.contains(row.id) {
                checkedIDs.insert(row.id)
            }
        }
    }

    // MARK: - Opslaan

    private func commit() {
        guard let selectedProvider else { return }
        let providerName = selectedProvider.displayName

        var byID = Dictionary(uniqueKeysWithValues: selectedChannels.map { ($0.id, $0) })

        // Zenders — ongewijzigd, per kanaal.
        for item in groupedLive.flatMap(\.items) {
            let key = "\(ShelfIPTVItemKind.live.rawValue):\(providerName):\(item.id)"
            if checkedIDs.contains(liveCompositeID(item)) {
                byID[key] = ShelfIPTVChannel(
                    channelID: item.id,
                    providerName: providerName,
                    name: item.name,
                    streamURL: item.streamURL,
                    logoURL: item.logoURL,
                    group: item.group,
                    kind: .live
                )
            } else {
                byID.removeValue(forKey: key)
            }
        }

        // VOD/Series — per aangevinkte categorie alle huidige titels als
        // snapshot toevoegen (of verwijderen als de categorie uitgevinkt is).
        for section in vodCategorySections {
            for row in section.rows {
                let isChecked = checkedIDs.contains(row.id)

                switch row.kind {
                case .vod:
                    for item in vodItemsByCategoryID[row.categoryID] ?? [] {
                        let key = "\(ShelfIPTVItemKind.vod.rawValue):\(providerName):\(item.id)"
                        if isChecked {
                            byID[key] = ShelfIPTVChannel(
                                channelID: item.id,
                                providerName: providerName,
                                name: item.name,
                                streamURL: item.streamURL,
                                logoURL: item.logoURL,
                                group: item.group,
                                kind: .vod
                            )
                        } else {
                            byID.removeValue(forKey: key)
                        }
                    }

                case .series:
                    for item in seriesItemsByCategoryID[row.categoryID] ?? [] {
                        let channelID = String(item.id)
                        let key = "\(ShelfIPTVItemKind.series.rawValue):\(providerName):\(channelID)"
                        if isChecked {
                            byID[key] = ShelfIPTVChannel(
                                channelID: channelID,
                                providerName: providerName,
                                name: item.name,
                                streamURL: nil,
                                logoURL: item.coverURL,
                                group: item.categoryID,
                                kind: .series
                            )
                        } else {
                            byID.removeValue(forKey: key)
                        }
                    }

                case .live:
                    break
                }
            }
        }

        selectedChannels = Array(byID.values)
    }
}
