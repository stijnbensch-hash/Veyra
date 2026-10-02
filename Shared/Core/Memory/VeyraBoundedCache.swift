import Foundation

/// Deterministic LRU with both count and byte-cost limits. Owner supplies isolation.
nonisolated struct VeyraBoundedCache<Key: Hashable, Value> {
    private struct Entry {
        let value: Value
        let cost: Int
        var access: UInt64
    }
    let countLimit: Int
    let costLimit: Int
    private var entries: [Key: Entry] = [:]
    private var clock: UInt64 = 0
    private(set) var totalCost = 0
    var count: Int { entries.count }

    init(countLimit: Int, costLimit: Int = .max) {
        self.countLimit = max(0, countLimit)
        self.costLimit = max(0, costLimit)
    }

    mutating func value(for key: Key) -> Value? {
        guard var entry = entries[key] else { return nil }
        clock &+= 1
        entry.access = clock
        entries[key] = entry
        return entry.value
    }

    func contains(_ key: Key) -> Bool { entries[key] != nil }

    mutating func insert(_ value: Value, for key: Key, cost: Int = 1) {
        if let old = entries.removeValue(forKey: key) { totalCost -= old.cost }
        let cost = max(0, cost)
        guard countLimit > 0, cost <= costLimit else { return }
        while !entries.isEmpty && (entries.count >= countLimit || totalCost > costLimit - cost) {
            guard let oldest = entries.min(by: { $0.value.access < $1.value.access })?.key,
                  let removed = entries.removeValue(forKey: oldest) else { break }
            totalCost -= removed.cost
        }
        clock &+= 1
        entries[key] = Entry(value: value, cost: cost, access: clock)
        totalCost += cost
    }

    mutating func removeAll() { entries.removeAll(); totalCost = 0 }
}
