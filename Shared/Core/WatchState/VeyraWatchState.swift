import Foundation

nonisolated struct VeyraWatchIdentity: Hashable, Codable, Sendable {
    let tmdbID: Int
    let season: Int?
    let episode: Int?

    var key: String { "\(tmdbID)|\(season ?? -1)|\(episode ?? -1)" }
}

nonisolated enum VeyraWatchSyncState: String, Codable, Sendable {
    case local
    case pendingHubSync
    case synced
}

nonisolated struct VeyraWatchState: Codable, Sendable, Hashable {
    let identity: VeyraWatchIdentity
    var progress: Double   // 0...100
    var watched: Bool
    var watchedAt: Date?
    var traktID: Int?
    var syncState: VeyraWatchSyncState
    var updatedAt: Date
}

actor VeyraWatchStateStore {
    static let shared = VeyraWatchStateStore()

    private static let defaultsKey = "veyra.watchState.v1"

    private var states: [String: VeyraWatchState] = [:]
    private var didLoad = false

    private init() {}

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        guard let data = UserDefaults.standard.data(forKey: Self.defaultsKey) else { return }
        guard let decoded = try? JSONDecoder().decode([String: VeyraWatchState].self, from: data) else { return }
        states = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(states) else { return }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }

    func state(_ identity: VeyraWatchIdentity) -> VeyraWatchState? {
        loadIfNeeded()
        return states[identity.key]
    }

    func states(forTMDBID tmdbID: Int) -> [VeyraWatchState] {
        loadIfNeeded()
        return states.values.filter { $0.identity.tmdbID == tmdbID }
    }

    @discardableResult
    func setProgress(_ identity: VeyraWatchIdentity, progress: Double, now: Date = Date()) -> VeyraWatchState {
        loadIfNeeded()
        var entry = states[identity.key] ?? VeyraWatchState(
            identity: identity,
            progress: 0,
            watched: false,
            watchedAt: nil,
            traktID: nil,
            syncState: .local,
            updatedAt: now
        )
        entry.progress = progress
        entry.updatedAt = now
        entry.syncState = .pendingHubSync
        if progress >= 90, !entry.watched {
            entry.watched = true
            entry.watchedAt = now
        }
        states[identity.key] = entry
        persist()
        notifyChanged()
        return entry
    }

    @discardableResult
    func setWatched(_ identity: VeyraWatchIdentity, watched: Bool, now: Date = Date()) -> VeyraWatchState {
        loadIfNeeded()
        var entry = states[identity.key] ?? VeyraWatchState(
            identity: identity,
            progress: 0,
            watched: false,
            watchedAt: nil,
            traktID: nil,
            syncState: .local,
            updatedAt: now
        )
        entry.watched = watched
        entry.watchedAt = watched ? now : nil
        if watched {
            entry.progress = 100
        }
        entry.updatedAt = now
        entry.syncState = .pendingHubSync
        states[identity.key] = entry
        persist()
        notifyChanged()
        return entry
    }

    // MARK: - VeyraHub sync (fase 8)
    //
    // `syncState` tracks whether a device's own last edit to an entry has
    // already reached the Hub. `pendingSync()`/`markSynced(_:)` are how
    // `VeyraHubWatchStateSyncService` finds what to upload and confirms what
    // landed -- this is the "offline queue" from spec §43: a change is
    // always saved here first (synchronous, local), and only *marked*
    // synced once a Hub round-trip actually succeeds, so a device that
    // never reaches the Hub simply keeps retrying on the next scheduled
    // sync without losing or blocking anything.

    func allStates() -> [VeyraWatchState] {
        loadIfNeeded()
        return Array(states.values)
    }

    func pendingSync() -> [VeyraWatchState] {
        loadIfNeeded()
        return states.values.filter { $0.syncState != .synced }
    }

    func markSynced(_ keys: [String], now: Date = Date()) {
        loadIfNeeded()
        for key in keys {
            guard var entry = states[key] else { continue }
            entry.syncState = .synced
            states[key] = entry
        }
        persist()
    }

    // MARK: - Trakt reconciliation (fase 9)

    /// Bevestigt een betrouwbare Trakt-koppeling voor deze identity -- zie
    /// `VeyraTraktWatchStateReconciler`. Verandert bewust geen `watched`/
    /// `progress`: dat gebeurt al via `setWatched`/`setProgress` zodra de
    /// reconciler daadwerkelijk ontbrekende historie samenvoegt.
    @discardableResult
    func setTraktID(_ identity: VeyraWatchIdentity, traktID: Int, now: Date = Date()) -> VeyraWatchState? {
        loadIfNeeded()
        guard var entry = states[identity.key] else { return nil }
        guard entry.traktID != traktID else { return entry }
        entry.traktID = traktID
        entry.updatedAt = now
        entry.syncState = .pendingHubSync
        states[identity.key] = entry
        persist()
        notifyChanged()
        return entry
    }

    /// Merges a batch of remote entries (fetched from the Hub) into the
    /// local store and returns the full merged snapshot. Union/merge
    /// semantics per spec §49/§50: watched episodes union, progress never
    /// regresses, partial progress is never silently discarded.
    @discardableResult
    func merge(remote: [VeyraWatchState]) -> [VeyraWatchState] {
        loadIfNeeded()
        for remoteEntry in remote {
            let key = remoteEntry.identity.key
            if let localEntry = states[key] {
                states[key] = Self.mergedEntry(local: localEntry, remote: remoteEntry)
            } else {
                var adopted = remoteEntry
                adopted.syncState = .synced
                states[key] = adopted
            }
        }
        persist()
        return Array(states.values)
    }

    private static func mergedEntry(local: VeyraWatchState, remote: VeyraWatchState) -> VeyraWatchState {
        guard local != remote else { return local }
        var merged = local
        merged.watched = local.watched || remote.watched
        merged.progress = merged.watched ? 100 : max(local.progress, remote.progress)
        if merged.watched {
            let candidates = [local.watchedAt, remote.watchedAt].compactMap { $0 }
            merged.watchedAt = candidates.min() ?? local.watchedAt ?? remote.watchedAt
        } else {
            merged.watchedAt = nil
        }
        merged.traktID = local.traktID ?? remote.traktID
        merged.updatedAt = max(local.updatedAt, remote.updatedAt)
        // Blijft `pendingHubSync` tot de gemergede waarde zelf succesvol
        // teruggeschreven is -- zie `VeyraHubWatchStateSyncService`.
        merged.syncState = .pendingHubSync
        return merged
    }

    private func notifyChanged() {
        NotificationCenter.default.post(name: .veyraWatchStateDidChange, object: nil)
    }
}

extension Notification.Name {
    static let veyraWatchStateDidChange = Notification.Name("veyraWatchStateDidChange")
}
