// MultiviewController.swift — gedeeld (tvOS/iPadOS)
// Bestuurt een grid van 2-4 gelijktijdige live-streams ("multiview"). Elk vak speelt zijn eigen
// zender af via een eigen PlaybackViewModel/AetherEngine-instantie -- los van elkaar, zodat een
// zender wisselen in één vak de andere vakken niet onderbreekt. Enkel het "actieve" vak (zie
// `activeIndex`) heeft geluid; de rest speelt gedempt door, net als bij sport-apps met multiview.

import Foundation

/// Eén vak in de multiview-grid: zijn eigen zender + eigen afspeel-viewmodel.
@MainActor
final class MultiviewSlot: ObservableObject, Identifiable {
    let id: Int
    @Published private(set) var channel: VeyraGuideChannel?
    @Published private(set) var viewModel: PlaybackViewModel?

    init(id: Int) {
        self.id = id
    }

    func setChannel(_ row: VeyraGuideChannel, guide: VeyraEPGStore) {
        viewModel?.stopForDisappear()
        channel = row
        let source = guide.play(row)
        let vm = PlaybackViewModel(
            source: source,
            item: MediaItem(title: row.channel.name, type: .liveTV),
            resumeProgress: nil
        )
        viewModel = vm
        Task { await vm.startPlayback() }
    }

    func stop() {
        viewModel?.stopForDisappear()
        viewModel = nil
        channel = nil
    }
}

@MainActor
final class MultiviewController: ObservableObject {
    @Published private(set) var slots: [MultiviewSlot] = []
    @Published private(set) var activeIndex = 0

    /// Start (of herstart) de grid met `count` vakken (2-4), gevuld met je favorieten in volgorde.
    /// Minder favorieten dan vakken: de overige vakken blijven leeg (zender later kiezen).
    func configure(count: Int, favorites: [VeyraGuideChannel], guide: VeyraEPGStore) {
        stopAll()
        slots = (0..<count).map { MultiviewSlot(id: $0) }
        for (index, slot) in slots.enumerated() where favorites.indices.contains(index) {
            slot.setChannel(favorites[index], guide: guide)
        }
        activeIndex = 0
    }

    func setActive(_ index: Int) {
        guard slots.indices.contains(index) else { return }
        activeIndex = index
    }

    func setChannel(_ row: VeyraGuideChannel, in index: Int, guide: VeyraEPGStore) {
        guard slots.indices.contains(index) else { return }
        slots[index].setChannel(row, guide: guide)
    }

    func stopAll() {
        for slot in slots { slot.stop() }
        slots = []
    }
}
