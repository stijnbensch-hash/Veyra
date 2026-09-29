// VeyraNowSettings.swift
// Instellingen voor "Veyra Now" (de tijdslijn-rail op Home, zie `VeyraContextRibbon.swift`):
// welke brontypes meedoen, of de prioriteit "slim" meeweegt (bv. een serie met nog maar
// 1 aflevering te gaan hoger dan een net gestarte film), en welke items de gebruiker zelf
// wegtikte ("Niet interessant" / "Vandaag niet") vanuit het lang-indruk-menu op een kaart.
// Zelfde opzet als `VeyraHomeLayout.swift`: één klein JSON-document in UserDefaults, en
// via `VeyraHubSyncService` (sleutel "veyra.now.settings") tussen apparaten gesynchroniseerd.

import Foundation

nonisolated struct VeyraNowSettings: Codable, Equatable, Sendable {
    var showReleases: Bool = true
    var smartPriority: Bool = true
    /// Blijvend weggetikt ("Niet interessant").
    var dismissedIDs: [String] = []
    /// Tijdelijk weggetikt ("Vandaag niet") -- komt terug zodra de bewaarde datum voorbij is.
    var snoozedUntil: [String: Date] = [:]

    static let standard = VeyraNowSettings()

    func isHidden(_ id: String, now: Date) -> Bool {
        if dismissedIDs.contains(id) { return true }
        if let until = snoozedUntil[id], until > now { return true }
        return false
    }
}

extension Notification.Name {
    static let veyraNowSettingsDidChange = Notification.Name("VeyraNowSettingsDidChange")
}

nonisolated enum VeyraNowSettingsStore {
    private static let key = "veyra.now.settings"

    static func load() -> VeyraNowSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let settings = try? JSONDecoder().decode(VeyraNowSettings.self, from: data) else { return .standard }
        return settings
    }

    static func save(_ settings: VeyraNowSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: key)
        NotificationCenter.default.post(name: .veyraNowSettingsDidChange, object: nil)
    }

    static func update(_ change: (inout VeyraNowSettings) -> Void) {
        var settings = load()
        change(&settings)
        save(settings)
    }

    static func dismiss(_ id: String) {
        update { settings in
            settings.snoozedUntil.removeValue(forKey: id)
            if !settings.dismissedIDs.contains(id) { settings.dismissedIDs.append(id) }
        }
    }

    /// "Vandaag niet": komt morgenochtend vroeg gewoon terug.
    static func snoozeForToday(_ id: String, now: Date = Date()) {
        let tomorrow = Calendar.current.startOfDay(for: now.addingTimeInterval(24 * 60 * 60))
        update { settings in settings.snoozedUntil[id] = tomorrow }
    }

    static func clearDismissedAndSnoozed() {
        update { settings in
            settings.dismissedIDs.removeAll()
            settings.snoozedUntil.removeAll()
        }
    }
}
