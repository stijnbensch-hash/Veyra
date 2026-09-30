// IPTVDiscoverySnapshotStore.swift — gedeeld (tvOS/iOS/iPadOS/macOS)
// Houdt per IPTV-provider/inhoudstype bij WANNEER elk item (VOD-ID,
// serie-ID, ...) voor het eerst gezien is -- de basis voor een "Nieuw
// toegevoegd"-sectie, los van de "added"-datum die de provider zelf
// meegeeft (niet elke provider/M3U levert die betrouwbaar).
//
// `contentType` is bewust een losse String (bv. "vod"/"series") i.p.v.
// `IPTVContentType` uit IPTVModels.swift -- dat voorkomt dat dit kleine,
// zelfstandige bestand de hele VOD/afspeel-typeboom (`IPTVVODItem` ->
// `PlayableSource` -> ...) mee moet compileren voor wie het losstaand wil
// gebruiken of testen.
//
// Storingsbestendig opgezet: `recordSuccessfulFetch` mag ALLEEN aangeroepen
// worden na een geslaagde, niet-lege ophaalbeurt. Bij een mislukte of lege
// ophaalbeurt (bv. provider tijdelijk onbereikbaar) roept de aanroeper dit
// gewoon niet aan -- de vorige snapshot blijft dan ongemoeid, zodat een
// tijdelijke storing nooit als "alles verwijderd" of "alles nieuw" wordt
// geïnterpreteerd.
import Foundation

nonisolated struct IPTVDiscoverySnapshotStore: Sendable {
    static let shared = IPTVDiscoverySnapshotStore()

    /// Hoelang een item nog als "nieuw" telt nadat het voor het eerst
    /// gezien is.
    static let newWindow: TimeInterval = 14 * 24 * 60 * 60

    private struct Snapshot: Codable, Sendable {
        var firstSeen: [String: Date] = [:]
        /// Laatste keer dat een succesvolle, niet-lege ophaalbeurt
        /// verwerkt is -- puur informatief, voor eventuele "laatst
        /// bijgewerkt"-weergave later.
        var lastSuccessfulFetch: Date?
    }

    private func cacheKey(providerID: UUID, contentType: String) -> String {
        "discovery-snapshot-\(providerID.uuidString)-\(contentType)"
    }

    struct DiffResult: Sendable {
        /// IDs die nu voor het eerst gezien zijn. Leeg bij de allereerste
        /// ophaalbeurt ooit voor deze provider/contentType (baseline) --
        /// anders zou een eerste gebruik meteen honderden "nieuw"-items
        /// tonen.
        let newItemIDs: Set<String>
        /// Sinds wanneer elk huidig item ooit voor het eerst gezien is
        /// (ook al langer bekende items) -- voor "nieuwste eerst"-sortering.
        let firstSeenByID: [String: Date]
    }

    /// Vergelijkt `currentIDs` (resultaat van een ZOJUIST geslaagde,
    /// niet-lege ophaalbeurt) met de vorige snapshot, werkt die bij en
    /// geeft terug welke IDs nieuw zijn.
    /// `IPTVDiskCache.write` schrijft op de achtergrond (fire-and-forget); deze
    /// functie is bewust `async` en wacht dat af (`IPTVDiskCache.flush()`) voor
    /// ze terugkeert, zodat een `recordSuccessfulFetch`/`currentFirstSeen` die
    /// vlak erna komt (of een tweede snel-opeenvolgende ophaalbeurt) altijd de
    /// zojuist geschreven snapshot leest i.p.v. een racende, nog niet
    /// weggeschreven versie.
    @discardableResult
    func recordSuccessfulFetch(
        providerID: UUID,
        contentType: String,
        currentIDs: Set<String>
    ) async -> DiffResult {
        let key = cacheKey(providerID: providerID, contentType: contentType)
        var snapshot = IPTVDiskCache.read(Snapshot.self, key: key)?.value ?? Snapshot()

        let isFirstEverSnapshot = snapshot.firstSeen.isEmpty && snapshot.lastSuccessfulFetch == nil
        let now = Date()

        var newItemIDs: Set<String> = []
        for id in currentIDs where snapshot.firstSeen[id] == nil {
            snapshot.firstSeen[id] = now
            if !isFirstEverSnapshot {
                newItemIDs.insert(id)
            }
        }

        // Items die nu niet meer in de catalogus staan opruimen -- veilig,
        // want de aanroeper garandeert dat dit alleen na een geslaagde,
        // niet-lege ophaalbeurt gebeurt (geen storings-valse-positieven).
        snapshot.firstSeen = snapshot.firstSeen.filter { currentIDs.contains($0.key) }
        snapshot.lastSuccessfulFetch = now

        IPTVDiskCache.write(snapshot, key: key)
        await IPTVDiskCache.flush()

        return DiffResult(newItemIDs: newItemIDs, firstSeenByID: snapshot.firstSeen)
    }

    /// Leest de laatst bekende "voor het eerst gezien"-datums zonder de
    /// snapshot te wijzigen -- voor UI die enkel wil sorteren/tonen zonder
    /// zelf net gefetcht te hebben.
    func currentFirstSeen(providerID: UUID, contentType: String) -> [String: Date] {
        let key = cacheKey(providerID: providerID, contentType: contentType)
        return IPTVDiskCache.read(Snapshot.self, key: key)?.value.firstSeen ?? [:]
    }

    /// Of een item met gegeven `firstSeen`-datum nog binnen het
    /// "nieuw"-venster valt.
    static func isWithinNewWindow(_ firstSeen: Date, now: Date = Date()) -> Bool {
        now.timeIntervalSince(firstSeen) <= newWindow
    }
}
