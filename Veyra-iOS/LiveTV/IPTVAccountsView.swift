import SwiftUI

extension Notification.Name {
    static let iptvConfigurationDidChange = Notification.Name("veyra.iptv.configurationDidChange")
}

struct IPTVAccountsView: View {
    @StateObject private var viewModel = IPTVAccountsViewModel()
    @State private var activeID: UUID?
    @State private var showAddSheet = false
    @State private var editingProvider: EditingProviderID?
    // Actieve/maximale gelijktijdige verbindingen per Xtream-provider (bv.
    // "1/2") -- per provider-ID gecachet zodat elke rij zijn eigen `.task`
    // maar één keer per verschijnen opvraagt.
    @State private var connectionStatus: [UUID: XtreamConnectionStatus] = [:]

    var body: some View {
        ZStack {
            VeyraColors.background.ignoresSafeArea()

            List {
            if viewModel.providers.isEmpty {
                ContentUnavailableView(
                    "Geen IPTV-providers",
                    systemImage: "antenna.radiowaves.left.and.right.slash",
                    description: Text("Voeg een M3U-playlist of Xtream-account toe.")
                )
            } else {
                Section {
                    ForEach(viewModel.providers) { provider in
                        NavigationLink {
                            IPTVProviderManagementLauncherView(
                                providerID: provider.id,
                                showsVOD: isXtream(provider)
                            )
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(providerStatusColor(for: provider.id))
                                            .frame(width: 10, height: 10)
                                            .accessibilityLabel(providerStatusLabel(for: provider.id))
                                        Text(provider.displayName)
                                            .foregroundStyle(.primary)
                                        if let status = connectionStatus[provider.id] {
                                            Text(status.display)
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(VeyraColors.cyan)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(VeyraColors.cyan.opacity(0.14), in: Capsule())
                                        }
                                    }
                                    Text(subtitle(for: provider))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if provider.id == activeID {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(VeyraColors.cyan)
                                }
                            }
                        }
                        .task(id: provider.id) {
                            await loadConnectionStatus(for: provider)
                        }
                        .swipeActions {
                            Button("Verwijderen", role: .destructive) {
                                viewModel.remove(provider)
                                refreshActiveID()
                            }
                            if provider.id != activeID {
                                Button("Actief maken") {
                                    viewModel.activate(provider)
                                    refreshActiveID()
                                }
                                .tint(VeyraColors.cyan)
                            }
                            Button("Bewerken") {
                                editingProvider = EditingProviderID(id: provider.id)
                            }
                            .tint(.blue)
                        }
                    }
                    .onMove { source, destination in
                        viewModel.moveProviders(fromOffsets: source, toOffset: destination)
                    }
                } header: {
                    Text("Providers")
                } footer: {
                    Text(
                        "Tik op een provider om Live TV en VOD in te stellen. Sleep om te herordenen - dit bepaalt de volgorde in de IPTV-lijst."
                    )
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("IPTV")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                #if os(iOS)
                EditButton()
                #endif
            }
        }
        .sheet(isPresented: $showAddSheet, onDismiss: reload) {
            NavigationStack {
                IPTVSetupView(providerID: nil, createsNewProvider: true)
            }
        }
        .sheet(item: $editingProvider, onDismiss: reload) { editing in
            NavigationStack {
                IPTVSetupView(providerID: editing.id, createsNewProvider: false)
            }
        }
        .onAppear(perform: reload)
        .onReceive(NotificationCenter.default.publisher(for: .iptvConfigurationDidChange)) { _ in reload() }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            viewModel.refreshStatus()
        }
    }

    /// Enkel voor Xtream-providers (M3U kent dit begrip niet) -- vraagt
    /// stil op de achtergrond op, faalt geruisloos (bv. server offline) zodat
    /// de lijst gewoon normaal blijft tonen zonder badge.
    private func loadConnectionStatus(for provider: IPTVStoredProvider) async {
        guard case .xtream(let configuration) = provider.configuration else { return }
        let status = try? await XtreamClient(configuration: configuration).connectionStatus()
        guard let status else { return }
        connectionStatus[provider.id] = status
    }

    private func subtitle(for provider: IPTVStoredProvider) -> String {
        switch provider.configuration {
        case .m3u(let configuration):
            return configuration.playlistURL.host ?? configuration.playlistURL.absoluteString
        case .xtream(let configuration):
            return configuration.serverURL.host ?? configuration.serverURL.absoluteString
        }
    }

    private func providerStatusColor(for id: UUID) -> Color {
        switch viewModel.onlineStatus[id] {
        case .some(true): .green
        case .some(false): .red
        case .none: .gray
        }
    }

    private func providerStatusLabel(for id: UUID) -> String {
        switch viewModel.onlineStatus[id] {
        case .some(true): "Provider bereikbaar"
        case .some(false): "Provider niet bereikbaar"
        case .none: "Providerstatus wordt gecontroleerd"
        }
    }

    private func reload() {
        viewModel.load()
        refreshActiveID()
    }

    private func refreshActiveID() {
        activeID = viewModel.activeProviderID()
    }
}

private struct EditingProviderID: Identifiable {
    let id: UUID
}

private func isXtream(_ provider: IPTVStoredProvider) -> Bool {
    if case .xtream = provider.configuration {
        return true
    }
    return false
}

/// Temporarily makes the given provider the "active" one so the
/// (otherwise active-provider-only) Live TV / VOD visibility screens
/// operate on it, then restores the previously active provider when
/// this view disappears. Mirrors the tvOS per-provider management launcher.
private struct IPTVProviderManagementLauncherView: View {
    let providerID: UUID
    let showsVOD: Bool

    @State private var isReady = false
    @State private var errorMessage: String?
    @State private var previousActiveProviderID: UUID?
    @State private var showEditSheet = false

    private let configurationStore = IPTVConfigurationStore()

    var body: some View {
        Group {
            if isReady {
                List {
                    NavigationLink {
                        IPTVLiveVisibilityView()
                    } label: {
                        Label("Live TV beheren", systemImage: "tv")
                    }

                    if showsVOD {
                        NavigationLink {
                            IPTVVODVisibilityView()
                        } label: {
                            Label("VOD beheren", systemImage: "film")
                        }
                    }

                    Button {
                        showEditSheet = true
                    } label: {
                        Label("Logingegevens bewerken", systemImage: "person.text.rectangle")
                    }
                }
                .scrollContentBackground(.hidden)
            } else if let errorMessage {
                ContentUnavailableView(
                    "Provider kon niet worden geopend",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else {
                ProgressView("Provider laden…")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VeyraColors.background)
        .navigationTitle("Beheren")
        .sheet(isPresented: $showEditSheet) {
            NavigationStack {
                IPTVSetupView(providerID: providerID, createsNewProvider: false)
            }
        }
        .task {
            prepareProvider()
        }
        .onDisappear {
            restorePreviousProvider()
        }
    }

    private func prepareProvider() {
        do {
            previousActiveProviderID = try configurationStore.activeProviderID()
            try configurationStore.setActiveProvider(id: providerID)
            isReady = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func restorePreviousProvider() {
        guard let previousActiveProviderID, previousActiveProviderID != providerID else {
            return
        }
        try? configurationStore.setActiveProvider(id: previousActiveProviderID)
    }
}

#Preview {
    NavigationStack { IPTVAccountsView() }
}
