import Foundation

/// VeyraHub Recorder-voorkeuren: automatisch verwijderen na kijken, en welke
/// series er als geheel worden opgenomen. Zie `VeyraHubRecorderClient`
/// (opname-API) en `VeyraHubRecorderCleanupTracker` (verwijdert na kijken).
enum RecorderSettingsDefaults {
    static let autoDeleteAfterWatchedKey = "recorder.autoDeleteAfterWatched"

    static func autoDeleteAfterWatched(from defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: autoDeleteAfterWatchedKey)
    }
}

/// Eén "neem hele serie op"-regel: alle nog niet uitgezonden EPG-programma's
/// op `channelID` waarvan de titel overeenkomt met `title` worden bij elke
/// nieuwe EPG-lading automatisch ingepland — zie `VeyraHubRecorderScheduler`.
/// `channelID` is `VeyraGuideChannel.id` (dezelfde rij als de opnameknop
/// zelf gebruikt), niet de EPG-eigen `tvgID`.
struct SeriesRecordingRule: Codable, Identifiable, Hashable {
    let channelID: String
    let title: String

    var id: String { Self.key(channelID: channelID, title: title) }

    static func key(channelID: String, title: String) -> String {
        "\(channelID)|\(title.lowercased())"
    }
}

enum SeriesRecordingDefaults {
    static let rulesKey = "recorder.seriesRules"

    static func loadRules(from defaults: UserDefaults = .standard) -> [SeriesRecordingRule] {
        guard let data = defaults.data(forKey: rulesKey),
              let rules = try? JSONDecoder().decode([SeriesRecordingRule].self, from: data) else {
            return []
        }
        return rules
    }

    static func saveRules(_ rules: [SeriesRecordingRule], to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        defaults.set(data, forKey: rulesKey)
    }

    static func isRecordingWholeSeries(
        channelID: String,
        title: String,
        from defaults: UserDefaults = .standard
    ) -> Bool {
        let key = SeriesRecordingRule.key(channelID: channelID, title: title)
        return loadRules(from: defaults).contains { $0.id == key }
    }

    /// Voegt de regel toe of verwijdert hem. Geeft de regel terug wanneer
    /// hij is toegevoegd (zodat de aanroeper meteen kan opnemen wat al in
    /// de geladen EPG staat), of nil wanneer hij is verwijderd of al
    /// bestond.
    @discardableResult
    static func setRecordingWholeSeries(
        _ enabled: Bool,
        channelID: String,
        title: String,
        to defaults: UserDefaults = .standard
    ) -> SeriesRecordingRule? {
        var rules = loadRules(from: defaults)
        let key = SeriesRecordingRule.key(channelID: channelID, title: title)
        if enabled {
            guard !rules.contains(where: { $0.id == key }) else { return nil }
            let rule = SeriesRecordingRule(channelID: channelID, title: title)
            rules.append(rule)
            saveRules(rules, to: defaults)
            return rule
        } else {
            rules.removeAll { $0.id == key }
            saveRules(rules, to: defaults)
            return nil
        }
    }
}
