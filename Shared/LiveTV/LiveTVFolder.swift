import Foundation

/// Door de gebruiker zelf aangemaakte map binnen Live TV, met kanalen uit één
/// of meerdere IPTV-providers (bv. een "Sport"-map met kanalen van zowel
/// provider A als provider B). Hergebruikt `ShelfIPTVChannel` (zie
/// `Shared/Shelves/Shelf.swift`) voor de kanaalsnapshots -- dat model was al
/// bewust provider-onafhankelijk opgezet voor de planken-functie, en is hier
/// één-op-één herbruikbaar.
///
/// Het logo van de map zelf wordt niet in dit model opgeslagen, maar via
/// `ChannelLogoOverrideStore` onder de sleutel `logoOverrideKey` -- zo
/// hergebruiken we de bestaande logo-zoek-/eigen-URL-UI (`ChannelLogoPickerView`,
/// zowel de tvOS- als iOS-versie) zonder een tweede opslagmechanisme te
/// bouwen. De sleutel begint met "folder:" zodat hij nooit botst met een
/// echte zender-ID (die altijd met "m3u-" of "xtream-live-" begint).
struct LiveTVFolder: Codable, Identifiable, Equatable, Hashable {
    var id: UUID
    var title: String
    var channels: [ShelfIPTVChannel]

    init(id: UUID = UUID(), title: String, channels: [ShelfIPTVChannel] = []) {
        self.id = id
        self.title = title
        self.channels = channels
    }

    var logoOverrideKey: String { "folder:\(id.uuidString)" }

    /// Effectief logo: een zelf gekozen mapoverzicht-logo indien aanwezig,
    /// anders het logo van het eerste kanaal in de map als redelijk fallback.
    var effectiveLogoURL: URL? {
        ChannelLogoOverrideStore.logoURL(forChannelID: logoOverrideKey) ?? channels.first?.logoURL
    }

    /// Aantal providers waar de kanalen in deze map vandaan komen -- gebruikt
    /// als subtitel ("2 providers · 8 kanalen") zodat meteen duidelijk is
    /// dat het om een map over providers heen gaat.
    var providerCount: Int {
        Set(channels.map(\.providerName)).count
    }

    var subtitle: String {
        let channelLabel = channels.count == 1 ? "1 kanaal" : "\(channels.count) kanalen"
        guard providerCount > 1 else { return channelLabel }
        return "\(providerCount) providers · \(channelLabel)"
    }
}
