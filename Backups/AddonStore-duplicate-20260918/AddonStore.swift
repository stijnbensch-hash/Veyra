import Foundation

struct AddonStore {
    private let defaults: UserDefaults
    private let key = "veyra.addons.v2"

    init(
        defaults: UserDefaults = .standard
    ) {
        self.defaults = defaults
    }

    // MARK: - Load

    func load() -> [AddonManifest] {
        guard
            let data = defaults.data(
                forKey: key
            ),
            let addons =
                try? JSONDecoder().decode(
                    [AddonManifest].self,
                    from: data
                )
        else {
            return []
        }

        return addons
    }

    /// Retourneert alleen de addons die enabled zijn
    func enabledAddons() -> [AddonManifest] {
        load().filter { $0.isEnabled }
    }

    // MARK: - Add

    func add(
        _ addon: AddonManifest
    ) throws {
        var addons = load()

        // Check voor duplicate URLs
        if addons.contains(where: {
            $0.baseURL == addon.baseURL
        }) {
            throw AddonStoreError.duplicateURL
        }

        // BELANGRIJK: Nieuwe addons zijn standaard enabled
        // tenzij expliciet anders aangegeven
        var newAddon = addon
        if !addons.isEmpty {
            // Als er al addons zijn, respecteer de isEnabled waarde
            // (standaard is true in AddonManifest init)
        }

        addons.append(newAddon)

        try save(addons)
    }

    // MARK: - Update

    func update(
        _ addon: AddonManifest
    ) throws {
        var addons = load()

        guard
            let index = addons.firstIndex(
                where: { $0.id == addon.id }
            )
        else {
            throw AddonStoreError.notFound
        }

        addons[index] = addon

        try save(addons)
    }

    // MARK: - Remove

    func remove(
        id: UUID
    ) throws {
        var addons = load()

        addons.removeAll {
            $0.id == id
        }

        try save(addons)
    }

    // MARK: - Save

    private func save(
        _ addons: [AddonManifest]
    ) throws {
        let data =
            try JSONEncoder().encode(
                addons
            )

        defaults.set(
            data,
            forKey: key
        )
    }
}

// MARK: - Errors

enum AddonStoreError: LocalizedError {
    case notFound
    case duplicateURL

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Deze addon kon niet worden gevonden."

        case .duplicateURL:
            return "Een addon met deze URL bestaat al."
        }
    }
}
