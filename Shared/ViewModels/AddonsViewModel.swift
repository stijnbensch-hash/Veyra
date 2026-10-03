import Foundation
import Combine

/// Bewerken van bestaande addonconfiguratie. De stores blijven nodig voor
/// metadata/catalogi en synchronisatie; er is geen lokale toevoegroute.
@MainActor
final class AddonsViewModel: ObservableObject {
    @Published private(set) var addons: [AddonManifest] = []
    @Published var errorMessage: String?

    private let store: AddonStore

    nonisolated init(store: AddonStore = AddonStore()) {
        self.store = store
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

    func update(_ addon: AddonManifest) throws {
        try store.update(addon)
        notifyAddonChange()
        reload()
    }

    /// Aan/uit-knop op het overzicht -- schakelt de addon zonder naar het
    /// bewerkscherm te hoeven navigeren.
    func toggleEnabled(_ addon: AddonManifest) {
        var updated = addon
        updated.isEnabled.toggle()
        do {
            try update(updated)
        } catch {
            errorMessage = error.localizedDescription
        }
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
