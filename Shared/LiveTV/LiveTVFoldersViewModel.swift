import Foundation

/// Gedeelde data/logica voor het Live TV-mappenscherm, gebruikt door zowel
/// de tvOS- als de iOS-versie. Zelfde opzet als `ShelvesViewModel`.
@MainActor
final class LiveTVFoldersViewModel: ObservableObject {
    @Published private(set) var folders: [LiveTVFolder] = []
    @Published var errorMessage: String?

    private let store: LiveTVFolderStore

    nonisolated init(store: LiveTVFolderStore = LiveTVFolderStore()) {
        self.store = store
    }

    func reload() {
        folders = store.load()
    }

    func add(_ folder: LiveTVFolder) {
        do {
            try store.add(folder)
            errorMessage = nil
            reload()
            notifyLiveTVFoldersChange()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func update(_ folder: LiveTVFolder) {
        do {
            try store.update(folder)
            errorMessage = nil
            reload()
            notifyLiveTVFoldersChange()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func remove(_ folder: LiveTVFolder) {
        do {
            try store.remove(id: folder.id)
            errorMessage = nil
            reload()
            notifyLiveTVFoldersChange()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        do {
            try store.move(fromOffsets: source, toOffset: destination)
            reload()
            notifyLiveTVFoldersChange()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
