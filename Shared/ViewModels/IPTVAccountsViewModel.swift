import Foundation
import Combine

/// Shared data/logic for the IPTV providers overview, used by both the
/// tvOS `IPTVAccountsView` and the iOS `IPTVAccountsView`.
@MainActor
final class IPTVAccountsViewModel: ObservableObject {
    @Published private(set) var providers: [IPTVStoredProvider] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    @Published private(set) var refreshingProviderIDs: Set<UUID> = []
    @Published private(set) var refreshMessages: [UUID: String] = [:]
    @Published private(set) var providerErrors: [UUID: String] = [:]

    private let configurationStore: IPTVConfigurationStore
    private let service: IPTVService

    nonisolated init(
        configurationStore: IPTVConfigurationStore = IPTVConfigurationStore(),
        service: IPTVService = IPTVService()
    ) {
        self.configurationStore = configurationStore
        self.service = service
    }

    var providerCountLabel: String {
        switch providers.count {
        case 0: return "Geen providers ingesteld"
        case 1: return "1 provider ingesteld"
        default: return "\(providers.count) providers ingesteld"
        }
    }

    func activeProviderID() -> UUID? {
        (try? configurationStore.activeProviderID()) ?? nil
    }

    func load() {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            providers = try configurationStore.loadProviders()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func remove(_ provider: IPTVStoredProvider) {
        do {
            try configurationStore.removeProvider(id: provider.id)
            NotificationCenter.default.post(name: .iptvConfigurationDidChange, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func activate(_ provider: IPTVStoredProvider) {
        do {
            try configurationStore.setActiveProvider(id: provider.id)
            NotificationCenter.default.post(name: .iptvConfigurationDidChange, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshProvider(_ provider: IPTVStoredProvider) async {
        guard !refreshingProviderIDs.contains(provider.id) else { return }

        refreshingProviderIDs.insert(provider.id)
        providerErrors[provider.id] = nil
        refreshMessages[provider.id] = nil

        defer { refreshingProviderIDs.remove(provider.id) }

        do {
            switch provider.configuration {
            case .xtream(let configuration):
                async let live = service.loadXtreamLiveCategories(configuration: configuration)
                async let vod = service.loadXtreamVODCategories(configuration: configuration)
                let result = try await (live, vod)

                refreshMessages[provider.id] =
                    "\(result.0.count) Live TV-categorieën en \(result.1.count) VOD-categorieën geladen."

            case .m3u(let configuration):
                let channels = try await service.loadM3UChannels(configuration: configuration)
                refreshMessages[provider.id] = "\(channels.count) zenders geladen."
            }

            NotificationCenter.default.post(name: .iptvConfigurationDidChange, object: nil)
        } catch {
            providerErrors[provider.id] = error.localizedDescription
        }
    }
}
