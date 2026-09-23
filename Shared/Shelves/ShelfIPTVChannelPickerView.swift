import SwiftUI

/// Laat de gebruiker losse IPTV-kanalen kiezen voor een plank
/// (`ShelfSource.iptv`) — desgewenst uit meerdere providers of categorieën
/// door dit scherm meerdere keren te openen. Werkt op tvOS en iOS.
struct ShelfIPTVChannelPickerView: View {
    @Binding var selectedChannels: [ShelfIPTVChannel]
    @Environment(\.dismiss) private var dismiss

    @State private var providers: [IPTVStoredProvider] = []
    @State private var selectedProviderID: UUID?
    @State private var groupedChannels: [(name: String, channels: [IPTVChannel])] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var checkedIDs: Set<String> = []

    private let configurationStore = IPTVConfigurationStore()
    private let service = IPTVService()

    private var selectedProvider: IPTVStoredProvider? {
        providers.first { $0.id == selectedProviderID }
    }

    var body: some View {
        List {
            if providers.count > 1 {
                Section("Provider") {
                    Picker("Provider", selection: $selectedProviderID) {
                        ForEach(providers) { provider in
                            Text(provider.displayName).tag(provider.id as UUID?)
                        }
                    }
                }
            }

            if isLoading {
                ProgressView("Kanalen laden…")
            } else if let errorMessage {
                Text(errorMessage).foregroundStyle(.secondary)
            } else if providers.isEmpty {
                Text("Stel eerst een IPTV-provider in bij Live TV.")
                    .foregroundStyle(.secondary)
            } else if groupedChannels.isEmpty {
                Text("Geen zenders gevonden voor deze provider.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(groupedChannels, id: \.name) { group in
                    Section(group.name) {
                        ForEach(group.channels) { channel in
                            channelRow(channel)
                        }
                    }
                }
            }
        }
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
            Task { await loadChannels() }
        }
    }

    // MARK: - Rij

    private func channelRow(_ channel: IPTVChannel) -> some View {
        let isChecked = checkedIDs.contains(compositeID(channel))

        return Button {
            toggle(channel)
        } label: {
            HStack(spacing: 14) {
                Text(ChannelNameOverrideStore.effectiveName(channelID: channel.id, defaultName: channel.name))
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isChecked ? VeyraColors.cyan : Color.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func compositeID(_ channel: IPTVChannel) -> String {
        "\(selectedProvider?.displayName ?? ""):\(channel.id)"
    }

    private func toggle(_ channel: IPTVChannel) {
        let key = compositeID(channel)
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

            // Al eerder voor deze plank gekozen kanalen blijven aangevinkt
            // als je dit scherm opnieuw opent (ook voor andere providers).
            checkedIDs = Set(selectedChannels.map(\.id))

            await loadChannels()
        } catch {
            errorMessage = "IPTV-providers konden niet worden geladen."
        }
    }

    private func loadChannels() async {
        guard let selectedProvider else {
            groupedChannels = []
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let channels: [IPTVChannel]
            switch selectedProvider.configuration {
            case .xtream(let xtream):
                channels = try await service.loadXtreamLiveChannels(configuration: xtream)
            case .m3u(let m3u):
                channels = try await service.loadM3UChannels(configuration: m3u)
                    .filter { $0.contentType == .live }
            }

            let grouped = Dictionary(grouping: channels) { channel -> String in
                let name = channel.group?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return name.isEmpty ? "Overige kanalen" : name
            }
            groupedChannels = grouped
                .map { (name: $0.key, channels: $0.value) }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            errorMessage = "Kanalen konden niet worden geladen: \(error.localizedDescription)"
            groupedChannels = []
        }
    }

    // MARK: - Opslaan

    private func commit() {
        guard let selectedProvider else { return }

        var byID = Dictionary(uniqueKeysWithValues: selectedChannels.map { ($0.id, $0) })
        let allChannels = groupedChannels.flatMap(\.channels)

        for channel in allChannels {
            let key = compositeID(channel)
            if checkedIDs.contains(key) {
                byID[key] = ShelfIPTVChannel(
                    channelID: channel.id,
                    providerName: selectedProvider.displayName,
                    name: ChannelNameOverrideStore.effectiveName(channelID: channel.id, defaultName: channel.name),
                    streamURL: channel.streamURL,
                    logoURL: channel.logoURL,
                    group: channel.group
                )
            } else {
                byID.removeValue(forKey: key)
            }
        }

        selectedChannels = Array(byID.values)
    }
}
