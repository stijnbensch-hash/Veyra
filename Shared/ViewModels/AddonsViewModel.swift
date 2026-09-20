import Foundation
import Combine

/// Shared data/logic for the addons settings screen, used by both the
/// tvOS `VeyraAddonsSettingsView` and the iOS `AddonsSettingsView`.
@MainActor
final class AddonsViewModel: ObservableObject {
    @Published private(set) var addons: [AddonManifest] = []
    @Published var errorMessage: String?

    private let store: AddonStore

    nonisolated init(store: AddonStore = AddonStore()) {
        self.store = store
    }

    func runMigrationIfNeeded() {
        AddonMigration().runIfNeeded()
    }

    func reload() {
        addons = store.load()
    }

    func remove(_ addon: AddonManifest) {
        do {
            try store.remove(id: addon.id)
            errorMessage = nil
            reload()
            notifyAddonChange()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func add(_ addon: AddonManifest) throws {
        try store.add(addon)
        notifyAddonChange()
        reload()
    }

    func update(_ addon: AddonManifest) throws {
        try store.update(addon)
        notifyAddonChange()
        reload()
    }

    func subtitle(for addon: AddonManifest) -> String {
        let host = addon.baseURL.host ?? addon.baseURL.absoluteString

        switch addon.kind {
        case .aioStreams:
            return "AIOStreams · \(host)"
        case .torrent:
            return "Torrent · \(host)"
        case .aioMetadata:
            return "AIOMetadata · \(host)"
        }
    }
}

extension Notification.Name {
    static let veyraAddonConfigurationDidChange = Notification.Name("VeyraAddonConfigurationDidChange")
}

func notifyAddonChange() {
    NotificationCenter.default.post(name: .veyraAddonConfigurationDidChange, object: nil)
}
