import Foundation
import Combine

/// Shared data/logic for the media servers settings screen, used by both
/// the tvOS `MediaServersSettingsView` and the iOS `MediaServersSettingsView`.
@MainActor
final class MediaServersViewModel: ObservableObject {
    @Published private(set) var servers: [MediaServerAccount] = []
    @Published var errorMessage: String?

    /// Online/offline-status per server, bijgewerkt door een lichte
    /// `System/Info/Public`-aanroep (zie `JellyfinClient.ping`). Ontbreekt
    /// een id nog in deze dictionary, dan is die server nog niet
    /// gecontroleerd — de UI toont dan een neutrale kleur i.p.v. meteen
    /// "offline".
    @Published private(set) var onlineStatus: [UUID: Bool] = [:]

    private let store: MediaServerStore
    private var statusCheckTask: Task<Void, Never>?

    nonisolated init(store: MediaServerStore = MediaServerStore()) {
        self.store = store
    }

    func reload() {
        servers = store.load()
        let knownIDs = Set(servers.map(\.id))
        onlineStatus = onlineStatus.filter { knownIDs.contains($0.key) }
        refreshStatus()
    }

    func remove(id: UUID) {
        do {
            try store.remove(id: id)
            errorMessage = nil
            reload()
            notifyMediaServerChange()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func add(_ server: MediaServerAccount) throws {
        try store.add(server)
        notifyMediaServerChange()
        reload()
    }

    func update(_ server: MediaServerAccount) throws {
        try store.update(server)
        notifyMediaServerChange()
        reload()
    }

    /// Ververst de online/offline-status van alle gekoppelde servers,
    /// parallel en zonder de UI te blokkeren. Een vorige, nog lopende
    /// controle wordt geannuleerd zodat snel-na-elkaar aanroepen (bv. elke
    /// `reload()`, of een periodieke timer op het scherm) elkaar niet
    /// opstapelen.
    func refreshStatus() {
        statusCheckTask?.cancel()
        let checkedServers = servers

        statusCheckTask = Task { @MainActor [weak self] in
            await withTaskGroup(of: (UUID, Bool, Bool).self) { group in
                for server in checkedServers {
                    group.addTask {
                        async let online = JellyfinClient.ping(serverURL: server.serverURL)
                        async let isHub = JellyfinClient.checkVeyraHub(serverURL: server.serverURL)
                        return (server.id, await online, await isHub)
                    }
                }

                for await (id, isOnline, isHub) in group {
                    guard let self, !Task.isCancelled else { continue }
                    self.onlineStatus[id] = isOnline
                    self.reconcileVeyraHubFlag(id: id, isVeyraHub: isHub, isOnline: isOnline)
                }
            }
        }
    }

    /// Herstelt `MediaServerAccount.isVeyraHub` wanneer deze lichte,
    /// niet-geauthenticeerde herprobe (hetzelfde `/System/Info/Public`-
    /// endpoint als bij het toevoegen van de server) een andere waarde
    /// oplevert dan wat er nu opgeslagen staat. Nodig omdat deze vlag
    /// anders alleen bijgewerkt wordt wanneer de gebruiker het wachtwoord
    /// opnieuw invoert bij het bewerken van de server — een verouderde,
    /// stil op `false` blijvende vlag blokkeerde anders permanent
    /// VeyraHub-native bronnen in het bronkeuzescherm. Alleen toegepast
    /// wanneer de server ook daadwerkelijk online is, zodat een tijdelijke
    /// netwerkstoring de vlag niet onterecht op `false` zet.
    private func reconcileVeyraHubFlag(id: UUID, isVeyraHub: Bool, isOnline: Bool) {
        guard isOnline, let index = servers.firstIndex(where: { $0.id == id }) else { return }
        guard servers[index].isVeyraHub != isVeyraHub else { return }

        var updated = servers[index]
        updated.isVeyraHub = isVeyraHub
        servers[index] = updated

        try? store.update(updated)
        notifyMediaServerChange()
    }
}
