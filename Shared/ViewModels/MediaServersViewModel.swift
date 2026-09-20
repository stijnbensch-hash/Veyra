import Foundation
import Combine

/// Shared data/logic for the media servers settings screen, used by both
/// the tvOS `MediaServersSettingsView` and the iOS `MediaServersSettingsView`.
@MainActor
final class MediaServersViewModel: ObservableObject {
    @Published private(set) var servers: [MediaServerAccount] = []
    @Published var errorMessage: String?

    private let store: MediaServerStore

    nonisolated init(store: MediaServerStore = MediaServerStore()) {
        self.store = store
    }

    func reload() {
        servers = store.load()
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
}
