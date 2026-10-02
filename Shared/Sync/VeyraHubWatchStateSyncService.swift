import Foundation

/// Syncs `VeyraWatchStateStore`'s local, canonical-identity-keyed watch
/// state across devices through a connected VeyraHub account -- Regional
/// Releases spec fase 8. Mirrors `VeyraHubSyncService`'s own
/// versioned-document + 409-retry pattern (same "veyra/v1/<name>" endpoint
/// family, same debounced-schedule shape), but keeps its own document
/// ("watchstate") because watch-state entries need real per-entry
/// union/merge (`VeyraWatchStateStore.merge(remote:)`) instead of that
/// service's whole-key last-writer-wins settings merge.
///
/// Local-first by design (spec §43): every write already landed in
/// `VeyraWatchStateStore` synchronously before this service ever runs --
/// playback is never blocked on this, and a Hub outage just leaves entries
/// `pendingHubSync` until the next scheduled attempt.
@MainActor
final class VeyraHubWatchStateSyncService {
    static let shared = VeyraHubWatchStateSyncService()

    private var started = false
    private var running = false
    private var scheduled: Task<Void, Never>?
    private var scheduledAt: Date?

    private init() {}

    func start() {
        guard !started else { return }
        started = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(changed),
            name: .veyraWatchStateDidChange, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(changed),
            name: .veyraMediaServerConfigurationDidChange, object: nil)
        schedule(after: 0)
    }

    @objc private func changed() { schedule(after: 2) }

    private func schedule(after seconds: TimeInterval) {
        if running { return }
        let fireAt = Date().addingTimeInterval(seconds)
        if let scheduledAt, scheduledAt <= fireAt { return }
        scheduled?.cancel()
        scheduledAt = fireAt
        scheduled = Task { [weak self] in
            if seconds > 0 {
                try? await Task.sleep(for: .seconds(seconds))
            }
            guard !Task.isCancelled else { return }
            self?.scheduled = nil
            self?.scheduledAt = nil
            await self?.sync()
        }
    }

    private func sync() async {
        guard !running else { return }
        running = true
        defer {
            running = false
            // Watch-state changes during playback are frequent; keep polling
            // on a shorter cadence than the generic settings sync so a
            // "pendingHubSync" entry doesn't sit unsynced for long.
            schedule(after: 60)
        }

        let accounts = MediaServerStore().load()
        for account in accounts where account.kind == .jellyfin {
            do {
                try await syncOnce(account: account)
                return
            } catch {
                continue
            }
        }
    }

    private struct Document {
        var version: Int
        var entries: [String: VeyraWatchState]
    }

    private func endpoint(account: MediaServerAccount) -> URL {
        account.serverURL.appendingPathComponent("veyra/v1/watchstate")
    }

    private func get(account: MediaServerAccount) async throws -> Document {
        var request = URLRequest(url: endpoint(account: account))
        request.setValue("Bearer \(account.accessToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = object["version"] as? Int
        else { throw URLError(.badServerResponse) }

        let content = object["data"] as? [String: Any] ?? [:]
        guard let entriesObject = content["entries"] as? [String: Any],
              let entriesData = try? JSONSerialization.data(withJSONObject: entriesObject),
              let entries = try? JSONDecoder().decode([String: VeyraWatchState].self, from: entriesData)
        else {
            return Document(version: version, entries: [:])
        }
        return Document(version: version, entries: entries)
    }

    private func put(account: MediaServerAccount, baseVersion: Int, entries: [String: VeyraWatchState]) async throws -> Bool {
        var request = URLRequest(url: endpoint(account: account))
        request.httpMethod = "PUT"
        request.timeoutInterval = 10
        request.setValue("Bearer \(account.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let entriesData = try JSONEncoder().encode(entries)
        let entriesObject = try JSONSerialization.jsonObject(with: entriesData)
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "baseVersion": baseVersion, "data": ["entries": entriesObject]
        ])

        let (_, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode
        if status == 409 { return false } // Someone else wrote first -- retry next scheduled round.
        guard status == 200 else { throw URLError(.badServerResponse) }
        return true
    }

    private func syncOnce(account: MediaServerAccount) async throws {
        let remote = try await get(account: account)
        let pendingBeforeMerge = await VeyraWatchStateStore.shared.pendingSync().map(\.identity.key)
        let merged = await VeyraWatchStateStore.shared.merge(remote: Array(remote.entries.values))

        let mergedByKey = Dictionary(uniqueKeysWithValues: merged.map { ($0.identity.key, $0) })
        guard mergedByKey != remote.entries else {
            // Nothing local to push; still confirm anything that was
            // already identical to what the Hub has.
            await VeyraWatchStateStore.shared.markSynced(pendingBeforeMerge)
            return
        }

        guard try await put(account: account, baseVersion: remote.version, entries: mergedByKey) else { return }
        await VeyraWatchStateStore.shared.markSynced(Array(mergedByKey.keys))
    }
}
