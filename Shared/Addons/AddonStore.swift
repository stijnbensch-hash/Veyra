import Foundation

struct AddonStore {
    private let defaults: UserDefaults

    private let storageKey =
        "veyra.addons.installed"

    init(
        defaults: UserDefaults = .standard
    ) {
        self.defaults = defaults
    }

    func load() -> [AddonManifest] {
        guard
            let data =
                defaults.data(
                    forKey: storageKey
                ),
            let addons =
                try? JSONDecoder()
                    .decode(
                        [AddonManifest].self,
                        from: data
                    )
        else {
            return []
        }

        return addons
    }

    func save(
        _ addons: [AddonManifest]
    ) throws {
        let data =
            try JSONEncoder()
                .encode(addons)

        defaults.set(
            data,
            forKey: storageKey
        )
    }

    func add(
        _ addon: AddonManifest
    ) throws {
        var addons = load()

        guard
            !addons.contains(
                where: {
                    $0.id == addon.id
                }
            )
        else {
            return
        }

        addons.append(addon)

        try save(addons)
    }

    func update(
        _ addon: AddonManifest
    ) throws {
        var addons = load()

        guard
            let index =
                addons.firstIndex(
                    where: {
                        $0.id == addon.id
                    }
                )
        else {
            try add(addon)
            return
        }

        addons[index] = addon

        try save(addons)
    }

    func remove(
        id: UUID
    ) throws {
        var addons = load()

        addons.removeAll {
            $0.id == id
        }

        try save(addons)
    }

    func enabledAddons()
        -> [AddonManifest]
    {
        load()
            .filter(\.isEnabled)
    }

    func contains(
        kind: AddonKind
    ) -> Bool {
        load().contains {
            $0.kind == kind
        }
    }
}
