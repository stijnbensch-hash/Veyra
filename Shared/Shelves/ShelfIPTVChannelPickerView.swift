import SwiftUI

/// Laat de gebruiker losse IPTV-kanalen of VOD-titels (films) kiezen voor
/// een plank (`ShelfSource.iptv`) — desgewenst uit meerdere providers of
/// categorieën door dit scherm meerdere keren te openen. Werkt op tvOS en
/// iOS. Bij VOD worden alleen titels getoond die in de IPTV-instellingen
/// ("VOD beheren") niet verborgen zijn — zo blijft de lijst behapbaar in
/// plaats van de volledige (soms enorme) providercatalogus te tonen.
struct ShelfIPTVChannelPickerView: View {
    @Binding var selectedChannels: [ShelfIPTVChannel]
    @Environment(\.dismiss) private var dismiss

    @State private var providers: [IPTVStoredProvider] = []
    @State private var selectedProviderID: UUID?
    @State private var contentKind: ShelfIPTVItemKind = .live
    @State private var groupedLive: [(name: String, items: [PickerItem])] = []
    @State private var groupedVOD: [(name: String, items: [PickerItem])] = []
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

    private var currentGroups: [(name: String, items: [PickerItem])] {
        contentKind == .live ? groupedLive : groupedVOD
    }

    /// Items gefilterd op de zoekopdracht — groepen zonder treffers
    /// vallen weg zodat de lijst overzichtelijk blijft bij veel zenders.
    private var filteredGroups: [(name: String, items: [PickerItem])] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return currentGroups }

        return currentGroups.compactMap { group -> (name: String, items: [PickerItem])? in
            let matches = group.items.filter { $0.name.localizedCaseInsensitiveContains(query) }
            return matches.isEmpty ? nil : (name: group.name, items: matches)
        }
    }

    private var emptyMessage: String {
        contentKind == .live ? "Geen zenders gevonden voor deze provider." : "Geen films gevonden voor deze provider."
    }

    private var searchEmptyMessage: String {
        contentKind == .live ? "Geen zenders gevonden voor '\(searchText)'." : "Geen films gevonden voor '\(searchText)'."
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
                    Text("Films").tag(ShelfIPTVItemKind.vod)
                }
                .pickerStyle(.segmented)
            }

            if isLoading {
                ProgressView(contentKind == .live ? "Kanalen laden…" : "Films laden…")
            } else if let errorMessage {
                Text(errorMessage).foregroundStyle(.secondary)
            } else if providers.isEmpty {
                Text("Stel eerst een IPTV-provider in bij Live TV.")
                    .foregroundStyle(.secondary)
            } else if currentGroups.isEmpty {
                Text(emptyMessage)
                    .foregroundStyle(.secondary)
            } else if filteredGroups.isEmpty {
                Text(searchEmptyMessage)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(filteredGroups, id: \.name) { group in
                    Section(group.name) {
                        ForEach(group.items) { item in
                            itemRow(item)
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: contentKind == .live ? "Zoek een kanaal" : "Zoek een film")
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
            groupedVOD = []
            vodLoaded = false
            Task { await loadGroups(kind: contentKind) }
        }
        .onChange(of: contentKind) { _, newValue in
            guard newValue == .vod, !vodLoaded else { return }
            Task { await loadGroups(kind: .vod) }
        }
    }

    // MARK: - Rij

    /// Gemeenschappelijke vorm voor een kanaal (live) of VOD-titel: allebei
    /// hebben ze rechtstreeks een afspeel-URL nodig, geen aparte behandeling.
    struct PickerItem: Identifiable, Hashable {
        let id: String
        let name: String
        let streamURL: URL
        let logoURL: URL?
        let group: String?
    }

    private func itemRow(_ item: PickerItem) -> some View {
        let isChecked = checkedIDs.contains(compositeID(item))

        return Button {
            toggle(item)
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

    private func compositeID(_ item: PickerItem) -> String {
        "\(contentKind.rawValue):\(selectedProvider?.displayName ?? ""):\(item.id)"
    }

    private func toggle(_ item: PickerItem) {
        let key = compositeID(item)
        if checkedIDs.contains(key) {
            checkedIDs.remove(key)
        } else {
            checkedIDs.insert(key)
        }
    }

    // MARK: - Laden

    private func loadProviders() async {
        do {
            providers = try configurationStore.loadProviders()
            selectedProviderID = providers.first?.id

            // Al eerder voor deze plank gekozen kanalen/films blijven
            // aangevinkt als je dit scherm opnieuw opent (ook voor andere
            // providers).
            checkedIDs = Set(selectedChannels.map(\.id))

            await loadGroups(kind: .live)
        } catch {
            errorMessage = "IPTV-providers konden niet worden geladen."
        }
    }

    private func loadGroups(kind: ShelfIPTVItemKind) async {
        guard let selectedProvider else {
            if kind == .live { groupedLive = [] } else { groupedVOD = [] }
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let items: [PickerItem]
            // Bij Xtream is `group` het ruwe categorie-ID (bv. "10"), geen
            // naam — daarom hier ook de categorieën ophalen en op ID naar
            // hun echte naam vertalen, net als in de Live TV/VOD-instellingen
            // (`IPTVLiveVisibilityView`/`IPTVVODVisibilityView`). Bij M3U is
            // de group al de echte naam.
            var categoryNamesByID: [String: String] = [:]
            let preferences = preferencesStore.load(for: selectedProvider.configuration)

            switch selectedProvider.configuration {
            case .xtream(let xtream):
                switch kind {
                case .live:
                    async let liveChannels = service.loadXtreamLiveChannels(configuration: xtream)
                    async let liveCategories = service.loadXtreamLiveCategories(configuration: xtream)
                    let (loadedChannels, categories) = try await (liveChannels, liveCategories)
                    categoryNamesByID = Dictionary(
                        categories.map { ($0.id, $0.name) },
                        uniquingKeysWith: { first, _ in first }
                    )
                    items = loadedChannels.map {
                        PickerItem(
                            id: $0.id,
                            name: ChannelNameOverrideStore.effectiveName(channelID: $0.id, defaultName: $0.name),
                            streamURL: $0.streamURL,
                            logoURL: $0.logoURL,
                            group: $0.group
                        )
                    }
                case .vod:
                    async let vodItems = service.loadXtreamVOD(configuration: xtream)
                    async let vodCategories = service.loadXtreamVODCategories(configuration: xtream)
                    let (loadedItems, categories) = try await (vodItems, vodCategories)
                    categoryNamesByID = Dictionary(
                        categories.map { ($0.id, $0.name) },
                        uniquingKeysWith: { first, _ in first }
                    )
                    items = loadedItems
                        .filter { item in
                            preferences.isVODItemVisible(item.id)
                                && (item.categoryID.map(preferences.isVODCategoryVisible) ?? true)
                        }
                        .map {
                            PickerItem(id: $0.id, name: $0.name, streamURL: $0.streamURL, logoURL: $0.posterURL, group: $0.categoryID)
                        }
                }
            case .m3u(let m3u):
                let contentType: IPTVContentType = kind == .live ? .live : .vod
                let channels = try await service.loadM3UChannels(configuration: m3u)
                    .filter { $0.contentType == contentType }
                items = channels.map {
                    PickerItem(
                        id: $0.id,
                        name: ChannelNameOverrideStore.effectiveName(channelID: $0.id, defaultName: $0.name),
                        streamURL: $0.streamURL,
                        logoURL: $0.logoURL,
                        group: $0.group
                    )
                }
            }

            let grouped = Dictionary(grouping: items) { item -> String in
                let rawGroup = item.group?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !rawGroup.isEmpty else { return "Overige kanalen" }
                return categoryNamesByID[rawGroup] ?? rawGroup
            }
            let sorted = grouped
                .map { (name: $0.key, items: $0.value) }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            if kind == .live {
                groupedLive = sorted
            } else {
                groupedVOD = sorted
                vodLoaded = true
            }
        } catch {
            let message = kind == .live
                ? "Kanalen konden niet worden geladen: \(error.localizedDescription)"
                : "Films konden niet worden geladen: \(error.localizedDescription)"
            errorMessage = message
            if kind == .live { groupedLive = [] } else { groupedVOD = [] }
        }
    }

    // MARK: - Opslaan

    private func commit() {
        guard let selectedProvider else { return }

        var byID = Dictionary(uniqueKeysWithValues: selectedChannels.map { ($0.id, $0) })
        let liveItems = groupedLive.flatMap(\.items)
        let vodItems = groupedVOD.flatMap(\.items)

        for (kind, allItems) in [(ShelfIPTVItemKind.live, liveItems), (.vod, vodItems)] {
            for item in allItems {
                let key = "\(kind.rawValue):\(selectedProvider.displayName):\(item.id)"
                if checkedIDs.contains(key) {
                    byID[key] = ShelfIPTVChannel(
                        channelID: item.id,
                        providerName: selectedProvider.displayName,
                        name: item.name,
                        streamURL: item.streamURL,
                        logoURL: item.logoURL,
                        group: item.group,
                        kind: kind
                    )
                } else {
                    byID.removeValue(forKey: key)
                }
            }
        }

        selectedChannels = Array(byID.values)
    }
}
