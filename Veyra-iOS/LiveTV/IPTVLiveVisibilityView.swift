import SwiftUI

/// Edits the same per-provider visibility preferences used by tvOS.
@MainActor
struct IPTVLiveVisibilityView: View {
    @State private var configuration: IPTVStoredConfiguration?
    @State private var groups: [LiveVisibilityGroup] = []
    @State private var channelsByGroup: [String: [IPTVChannel]] = [:]
    @State private var preferences = IPTVProviderPreferences()
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let configurationStore = IPTVConfigurationStore()
    private let preferencesStore = IPTVProviderPreferencesStore()
    private let service = IPTVService()

    var body: some View {
        Group {
            Group {
                if isLoading && groups.isEmpty {
                    ProgressView("Kanalen laden…")
                } else if let errorMessage, groups.isEmpty {
                    ContentUnavailableView(
                        "Kanalen konden niet worden geladen",
                        systemImage: "wifi.exclamationmark",
                        description: Text(errorMessage)
                    )
                } else if groups.isEmpty {
                    ContentUnavailableView(
                        "Geen kanalen gevonden",
                        systemImage: "tv"
                    )
                } else {
                    List(groups) { group in
                        NavigationLink {
                            IPTVChannelVisibilityView(
                                group: group,
                                channels: channelsByGroup[group.id] ?? [],
                                preferences: $preferences,
                                onSave: save
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(group.name)
                                    .foregroundStyle(.primary)
                                Text(status(for: group))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(VeyraColors.background)
            .navigationTitle("Kanalen beheren")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Alles zichtbaar maken", systemImage: "eye") {
                            var updated = preferences
                            updated.hiddenLiveCategoryIDs.removeAll()
                            updated.hiddenLiveChannelIDs.removeAll()
                            save(updated)
                        }
                        Button("Alles verbergen", systemImage: "eye.slash") {
                            var updated = preferences
                            updated.hiddenLiveCategoryIDs = Set(groups.map(\.id))
                            updated.hiddenLiveChannelIDs.removeAll()
                            save(updated)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .disabled(groups.isEmpty)
                }
            }
            .task { await load() }
            .onReceive(NotificationCenter.default.publisher(for: .iptvConfigurationDidChange)) { _ in
                if let configuration {
                    preferences = preferencesStore.load(for: configuration)
                }
            }
        }
    }

    private func status(for group: LiveVisibilityGroup) -> String {
        guard preferences.isLiveCategoryVisible(group.id) else {
            return "Categorie verborgen"
        }
        let channels = channelsByGroup[group.id] ?? []
        let visible = channels.filter { preferences.isLiveChannelVisible($0.id) }.count
        return "\(visible) van \(channels.count) kanalen zichtbaar"
    }

    private func save(_ updated: IPTVProviderPreferences) {
        guard let configuration else { return }
        do {
            try preferencesStore.save(updated, for: configuration)
            preferences = updated
            errorMessage = nil
            NotificationCenter.default.post(name: .iptvConfigurationDidChange, object: nil)
        } catch {
            errorMessage = "De zichtbaarheid kon niet worden opgeslagen."
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            guard let configuration = try configurationStore.load() else {
                errorMessage = "Stel eerst een IPTV-provider in."
                return
            }
            self.configuration = configuration
            preferences = preferencesStore.load(for: configuration)

            let loadedGroups: [LiveVisibilityGroup]
            let channels: [IPTVChannel]
            switch configuration {
            case .xtream(let xtream):
                let categories = try await service.loadXtreamLiveCategories(configuration: xtream)
                try Task.checkCancellation()
                channels = try await service.loadXtreamLiveChannels(configuration: xtream)
                loadedGroups = categories.map { LiveVisibilityGroup(id: $0.id, name: $0.name) }
            case .m3u(let m3u):
                channels = try await service.loadM3UChannels(configuration: m3u)
                let names = Set(channels.map(\.iptvPreferenceGroupName))
                loadedGroups = names.map {
                    LiveVisibilityGroup(
                        id: IPTVChannel.iptvPreferenceGroupID($0),
                        name: $0
                    )
                }
            }
            try Task.checkCancellation()

            let grouped = Dictionary(grouping: channels) { channel in
                switch configuration {
                case .xtream:
                    return channel.group ?? ""
                case .m3u:
                    return IPTVChannel.iptvPreferenceGroupID(channel.iptvPreferenceGroupName)
                }
            }
            let knownIDs = Set(loadedGroups.map(\.id))
            let missingGroups = grouped.keys
                .filter { !knownIDs.contains($0) }
                .map { LiveVisibilityGroup(id: $0, name: $0.isEmpty ? "Overige kanalen" : $0) }
            groups = (loadedGroups + missingGroups).sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            channelsByGroup = grouped
        } catch is CancellationError {
        } catch {
            errorMessage = "Controleer de verbinding met je IPTV-provider en probeer opnieuw."
        }
    }
}

private struct LiveVisibilityGroup: Identifiable {
    let id: String
    let name: String
}

@MainActor
private struct IPTVChannelVisibilityView: View {
    let group: LiveVisibilityGroup
    let channels: [IPTVChannel]
    @Binding var preferences: IPTVProviderPreferences
    let onSave: (IPTVProviderPreferences) -> Void

    @State private var searchText = ""

    private var filteredChannels: [IPTVChannel] {
        guard !searchText.isEmpty else { return channels }
        return channels.filter {
            ChannelNameOverrideStore.effectiveName(
                channelID: $0.id, defaultName: $0.name
            ).localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            Section {
                Toggle(
                    "Categorie zichtbaar",
                    isOn: Binding(
                        get: { preferences.isLiveCategoryVisible(group.id) },
                        set: { visible in
                            var updated = preferences
                            updated.setLiveCategory(group.id, visible: visible)
                            onSave(updated)
                        }
                    )
                )
                .tint(VeyraColors.cyan)
            } footer: {
                Text("Een verborgen categorie verbergt al haar kanalen. De keuzes per kanaal blijven bewaard.")
            }

            Section("Kanalen") {
                ForEach(filteredChannels) { channel in
                    Toggle(
                        isOn: Binding(
                            get: { preferences.isLiveChannelVisible(channel.id) },
                            set: { visible in
                                var updated = preferences
                                updated.setLiveChannel(channel.id, visible: visible)
                                onSave(updated)
                            }
                        )
                    ) {
                        HStack(spacing: 12) {
                            AsyncImage(url: ChannelLogoOverrideStore.effectiveLogoURL(
                                channelID: channel.id, defaultLogoURL: channel.logoURL
                            )) { phase in
                                if let image = phase.image {
                                    image.resizable().scaledToFit()
                                } else {
                                    Image(systemName: "tv").foregroundStyle(.secondary)
                                }
                            }
                            .frame(width: 40, height: 36)
                            Text(ChannelNameOverrideStore.effectiveName(
                                channelID: channel.id, defaultName: channel.name
                            ))
                        }
                    }
                    .tint(VeyraColors.cyan)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(VeyraColors.background)
        .navigationTitle(group.name)
        .searchable(text: $searchText, prompt: "Zoek kanalen")
    }
}
