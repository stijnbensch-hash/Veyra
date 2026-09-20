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
}
