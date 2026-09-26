// VeyraHeroSpotlightController.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// Laadt de Home-hero-items op basis van de opgeslagen instellingen. Herlaadt
// niet zelf via een NotificationCenter-observer (dat gaf onder Swift 6
// strict concurrency problemen met een main-actor-geïsoleerde deinit) --
// de aanroepende view luistert zelf naar `.heroSpotlightSettingsChanged`
// via `.onReceive(...)`, net als de andere Home-instellingen
// (zie `.veyraHomeLayoutDidChange` in VeyraBentoHomeIOS.swift), en roept
// dan `settingsChanged()` aan.

import Foundation
import Observation

@MainActor
@Observable
final class VeyraHeroSpotlightController {
    private(set) var settings: HeroSpotlightSettings
    private(set) var items: [HeroSpotlightItem] = []

    /// Index van de momenteel getoonde carrousel-slide -- bijgehouden door
    /// `VeyraHeroSpotlightView` (via `onIndexChange`) zodat een scherm dat de
    /// achtergrond BUITEN zijn ScrollView om moet tekenen (zie `externalBackdrop`
    /// bij die view) weet welke afbeelding daar moet komen.
    var currentIndex = 0
    var current: HeroSpotlightItem? {
        items.indices.contains(currentIndex) ? items[currentIndex] : nil
    }

    private let store: HeroSpotlightSettingsStore
    private var loadTask: Task<Void, Never>?

    init(store: HeroSpotlightSettingsStore = HeroSpotlightSettingsStore()) {
        self.store = store
        self.settings = store.load()
    }

    func reloadIfNeeded() {
        guard items.isEmpty, loadTask == nil else { return }
        reload()
    }

    /// Aanroepen vanuit `.onReceive(... .heroSpotlightSettingsChanged ...)`
    /// wanneer Instellingen → Home → Hero gewijzigd is.
    func settingsChanged() {
        settings = store.load()
        reload()
    }

    private func reload() {
        loadTask?.cancel()
        let current = settings
        loadTask = Task { [weak self] in
            let loaded = await HeroSpotlightLoader.load(settings: current)
            guard !Task.isCancelled else { return }
            self?.items = loaded
            self?.loadTask = nil
        }
    }
}
