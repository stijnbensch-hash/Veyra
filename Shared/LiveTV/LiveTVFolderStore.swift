import Foundation

/// Opslag voor de door de gebruiker aangemaakte Live TV-mappen
/// (`LiveTVFolder`), als eenvoudige JSON-array in `UserDefaults` -- exact
/// hetzelfde patroon als `ShelfStore`.
struct LiveTVFolderStore {
    private let defaults: UserDefaults
    private let storageKey = "veyra.livetv.folders.configured"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [LiveTVFolder] {
        guard let data = defaults.data(forKey: storageKey),
              let folders = try? JSONDecoder().decode([LiveTVFolder].self, from: data)
        else { return [] }
        return folders
    }

    func save(_ folders: [LiveTVFolder]) throws {
        let data = try JSONEncoder().encode(folders)
        defaults.set(data, forKey: storageKey)
    }

    func add(_ folder: LiveTVFolder) throws {
        var folders = load()
        guard !folders.contains(where: { $0.id == folder.id }) else { return }
        folders.append(folder)
        try save(folders)
    }

    func update(_ folder: LiveTVFolder) throws {
        var folders = load()
        guard let index = folders.firstIndex(where: { $0.id == folder.id }) else {
            try add(folder)
            return
        }
        folders[index] = folder
        try save(folders)
    }

    func remove(id: UUID) throws {
        var folders = load()
        folders.removeAll { $0.id == id }
        try save(folders)

        // Ook het eventuele eigen mapoverzicht-logo opruimen, anders blijft
        // dat als wees achter in `ChannelLogoOverrideStore`.
        ChannelLogoOverrideStore.removeOverride(forChannelID: "folder:\(id.uuidString)")
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) throws {
        var folders = load()

        let moving = source.sorted().map { folders[$0] }
        for index in source.sorted(by: >) {
            folders.remove(at: index)
        }

        let adjustedDestination = destination - source.filter { $0 < destination }.count
        let insertionIndex = min(max(0, adjustedDestination), folders.count)

        folders.insert(contentsOf: moving, at: insertionIndex)
        try save(folders)
    }
}

extension Notification.Name {
    static let veyraLiveTVFoldersDidChange = Notification.Name("VeyraLiveTVFoldersDidChange")
}

func notifyLiveTVFoldersChange() {
    NotificationCenter.default.post(name: .veyraLiveTVFoldersDidChange, object: nil)
}
