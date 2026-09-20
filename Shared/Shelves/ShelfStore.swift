import Foundation

struct ShelfStore {
    private let defaults: UserDefaults
    private let storageKey = "veyra.shelves.configured"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [Shelf] {
        guard let data = defaults.data(forKey: storageKey),
              let shelves = try? JSONDecoder().decode([Shelf].self, from: data)
        else { return [] }
        return shelves
    }

    func save(_ shelves: [Shelf]) throws {
        let data = try JSONEncoder().encode(shelves)
        defaults.set(data, forKey: storageKey)
    }

    func add(_ shelf: Shelf) throws {
        var shelves = load()
        guard !shelves.contains(where: { $0.id == shelf.id }) else { return }
        shelves.append(shelf)
        try save(shelves)
    }

    func update(_ shelf: Shelf) throws {
        var shelves = load()
        guard let index = shelves.firstIndex(where: { $0.id == shelf.id }) else {
            try add(shelf)
            return
        }
        shelves[index] = shelf
        try save(shelves)
    }

    func remove(id: UUID) throws {
        var shelves = load()
        shelves.removeAll { $0.id == id }
        try save(shelves)
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) throws {
        var shelves = load()

        let moving = source.sorted().map { shelves[$0] }
        for index in source.sorted(by: >) {
            shelves.remove(at: index)
        }

        // Herbereken de invoegpositie: elke bron-index vóór de oorspronkelijke
        // `destination` telt mee in hoeveel de doelpositie na verwijdering opschuift.
        let adjustedDestination = destination - source.filter { $0 < destination }.count
        let insertionIndex = min(max(0, adjustedDestination), shelves.count)

        shelves.insert(contentsOf: moving, at: insertionIndex)
        try save(shelves)
    }

    func enabledShelves() -> [Shelf] {
        load().filter(\.isEnabled)
    }
}

extension Notification.Name {
    static let veyraShelfConfigurationDidChange = Notification.Name("VeyraShelfConfigurationDidChange")
}

func notifyShelfChange() {
    NotificationCenter.default.post(name: .veyraShelfConfigurationDidChange, object: nil)
}
