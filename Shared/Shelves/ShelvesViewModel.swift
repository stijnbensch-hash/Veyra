import Foundation
import Combine

/// Gedeelde data/logica voor het "Planken"-instellingenscherm, gebruikt door
/// zowel de tvOS- als de iOS-versie.
@MainActor
final class ShelvesViewModel: ObservableObject {
    @Published private(set) var shelves: [Shelf] = []
    @Published var errorMessage: String?

    private let store: ShelfStore

    nonisolated init(store: ShelfStore = ShelfStore()) {
        self.store = store
    }

    func reload() {
        shelves = store.load()
    }

    func add(_ shelf: Shelf) {
        do {
            try store.add(shelf)
            errorMessage = nil
            reload()
            notifyShelfChange()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func update(_ shelf: Shelf) {
        do {
            try store.update(shelf)
            errorMessage = nil
            reload()
            notifyShelfChange()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func remove(_ shelf: Shelf) {
        do {
            try store.remove(id: shelf.id)
            errorMessage = nil
            reload()
            notifyShelfChange()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setEnabled(_ enabled: Bool, for shelf: Shelf) {
        var updated = shelf
        updated.isEnabled = enabled
        update(updated)
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        do {
            try store.move(fromOffsets: source, toOffset: destination)
            reload()
            notifyShelfChange()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
