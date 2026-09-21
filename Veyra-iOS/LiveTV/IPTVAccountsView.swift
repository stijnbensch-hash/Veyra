import SwiftUI

extension Notification.Name {
    static let iptvConfigurationDidChange = Notification.Name("veyra.iptv.configurationDidChange")
}

struct IPTVAccountsView: View {
    @StateObject private var viewModel = IPTVAccountsViewModel()
    @State private var activeID: UUID?
    @State private var showAddSheet = false
    @State private var editingProvider: EditingProviderID?

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
                        Button {
                            editingProvider = EditingProviderID(id: provider.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(provider.displayName)
                                        .foregroundStyle(.primary)
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
                        }
                    }
                    .onMove { source, destination in
                        viewModel.moveProviders(fromOffsets: source, toOffset: destination)
                    }
                } header: {
                    Text("Providers")
                } footer: {
                    Text("Sleep om te herordenen. Dit bepaalt de volgorde in de IPTV-lijst.")
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
                EditButton()
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
    }

    private func subtitle(for provider: IPTVStoredProvider) -> String {
        switch provider.configuration {
        case .m3u(let configuration):
            return configuration.playlistURL.host ?? configuration.playlistURL.absoluteString
        case .xtream(let configuration):
            return configuration.serverURL.host ?? configuration.serverURL.absoluteString
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

#Preview {
    NavigationStack { IPTVAccountsView() }
}
