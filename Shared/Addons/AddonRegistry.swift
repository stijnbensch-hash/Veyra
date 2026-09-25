import Foundation

struct RegisteredAddonProvider {
    let addonName: String
    let provider: any MediaSourceProvider
}

struct AddonRegistry {
    private let store:
        AddonStore

    init(
        store:
            AddonStore =
                AddonStore()
    ) {
        self.store = store
    }

    // MARK: - Providers

    func registeredProviders()
        -> [RegisteredAddonProvider]
    {
        store
            .enabledAddons()
            .map { addon in
                let cleanName =
                    addon.name
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )

                let displayName =
                    cleanName.isEmpty
                        ? "Stremio Addon"
                        : cleanName

                let provider =
                    StremioAddonProvider(
                        name:
                            displayName,
                        baseURL:
                            addon.baseURL
                    )

                return RegisteredAddonProvider(
                    addonName:
                        displayName,
                    provider:
                        provider
                )
            }
    }

    // MARK: - Compatibility

    func providers()
        -> [any MediaSourceProvider]
    {
        registeredProviders()
            .map(
                \.provider
            )
    }

    // MARK: - Bronvolgorde

    /// Namen van addons die daadwerkelijk streams kunnen leveren, dus met
    /// uitzondering van metadata-only addons (zoals AIOMetadata) die geen
    /// stream-resource aanbieden en dus nooit als knop in "Selecteer bron"
    /// verschijnen. Gebruikt voor de Bronvolgorde-instelling, zodat daar
    /// geen namen staan die toch nooit een bron opleveren.
    func streamProviderNames() -> [String] {
        store
            .enabledAddons()
            .filter { $0.kind != .aioMetadata }
            .map { addon in
                let cleanName =
                    addon.name
                        .trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )

                return cleanName.isEmpty
                    ? "Stremio Addon"
                    : cleanName
            }
    }
}
