import SwiftUI

struct IPTVProviderPickerView: View {
    private let configurationStore = IPTVConfigurationStore()

    @State private var providers: [IPTVStoredProvider] = []
    @State private var activeProviderID: UUID?
    @State private var isShowingProviders = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                loadProviders()

                if !providers.isEmpty && errorMessage == nil {
                    isShowingProviders = true
                }
            } label: {
                HStack(spacing: 12) {
                    Image(
                        systemName: "antenna.radiowaves.left.and.right"
                    )

                    Text("Provider: \(activeProviderName)")
                        .lineLimit(1)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                }
                .font(.system(size: 20, weight: .semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .buttonStyle(.bordered)
            .tint(.cyan)
            .disabled(providers.isEmpty)
            .confirmationDialog(
                "Kies een IPTV-provider",
                isPresented: $isShowingProviders,
                titleVisibility: .visible
            ) {
                ForEach(providers) { provider in
                    Button(selectionTitle(for: provider)) {
                        select(provider)
                    }
                }

                Button("Annuleren", role: .cancel) {}
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Opnieuw laden") {
                    loadProviders()
                }
                .buttonStyle(.bordered)
            } else if providers.isEmpty {
                Text("Voeg een provider toe via Instellingen → IPTV.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            loadProviders()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .iptvConfigurationDidChange
            )
        ) { _ in
            loadProviders()
        }
    }

    private var activeProviderName: String {
        providers.first {
            $0.id == activeProviderID
        }?.displayName
            ?? providers.first?.displayName
            ?? "Geen provider"
    }

    private func selectionTitle(
        for provider: IPTVStoredProvider
    ) -> String {
        if provider.id == activeProviderID {
            return "\(provider.displayName) (actief)"
        }

        return provider.displayName
    }

    private func loadProviders() {
        errorMessage = nil

        do {
            let loadedProviders = try configurationStore.loadProviders()
            let storedActiveID = try configurationStore.activeProviderID()

            providers = loadedProviders

            if let storedActiveID,
               loadedProviders.contains(where: { $0.id == storedActiveID }) {
                activeProviderID = storedActiveID
            } else {
                activeProviderID = loadedProviders.first?.id
            }
        } catch {
            providers = []
            activeProviderID = nil
            errorMessage = error.localizedDescription
        }
    }

    private func select(
        _ provider: IPTVStoredProvider
    ) {
        guard provider.id != activeProviderID else {
            return
        }

        errorMessage = nil

        do {
            try configurationStore.setActiveProvider(
                id: provider.id
            )

            activeProviderID = provider.id

            NotificationCenter.default.post(
                name: .iptvConfigurationDidChange,
                object: nil
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
