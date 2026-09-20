import Foundation

struct AddonMigration {
    private let store:
        AddonStore

    private let defaults:
        UserDefaults

    private let migrationKey =
        "veyra.addons.migration.aioStreams.v1"

    init(
        store: AddonStore =
            AddonStore(),
        defaults: UserDefaults =
            .standard
    ) {
        self.store = store
        self.defaults = defaults
    }

    func runIfNeeded() {
        guard
            !defaults.bool(
                forKey: migrationKey
            )
        else {
            return
        }

        defer {
            defaults.set(
                true,
                forKey: migrationKey
            )
        }

        guard
            !store.contains(
                kind: .aioStreams
            ),
            let url =
                AppConfiguration
                    .aioStreamsBaseURL
        else {
            return
        }

        let addon =
            AddonManifest(
                name: "AIOStreams",
                kind: .aioStreams,
                baseURL: url,
                isEnabled: true
            )

        try? store.add(addon)
    }
}
