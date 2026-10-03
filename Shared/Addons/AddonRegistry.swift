import Foundation

struct RegisteredAddonProvider {
    let addonName: String
    let provider: any MediaSourceProvider
}

/// Geen rechtstreekse addonstreams meer in Veyra. VeyraHub levert zijn
/// addonbronnen via JellyfinSourceProvider / VeyraHubNativeClient.
/// AddonStore blijft bestaan voor gesynchroniseerde metadata en catalogi.
struct AddonRegistry {
    init(store: AddonStore = AddonStore()) {}

    func registeredProviders() -> [RegisteredAddonProvider] { [] }

    func providers() -> [any MediaSourceProvider] { [] }

    func streamProviderNames() -> [String] { [] }
}
