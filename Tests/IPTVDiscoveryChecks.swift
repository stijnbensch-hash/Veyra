import Foundation

@main
struct IPTVDiscoveryChecks {
    static func main() async {
        let store = IPTVDiscoverySnapshotStore.shared
        let providerA = UUID()
        let providerB = UUID()

        // Opschonen van eventuele resten van een eerdere testrun.
        IPTVDiskCache.remove(key: "discovery-snapshot-\(providerA.uuidString)-vod")
        IPTVDiskCache.remove(key: "discovery-snapshot-\(providerB.uuidString)-vod")

        // 1. Allereerste ophaalbeurt ooit: baseline, geen enkel item is "nieuw".
        let first = await store.recordSuccessfulFetch(
            providerID: providerA,
            contentType: "vod",
            currentIDs: ["a", "b", "c"]
        )
        precondition(first.newItemIDs.isEmpty, "Eerste ophaalbeurt mag nooit 'nieuw' opleveren (baseline)")
        precondition(first.firstSeenByID.count == 3)

        // 2. Tweede ophaalbeurt met één extra item: alleen dat item is nieuw.
        let second = await store.recordSuccessfulFetch(
            providerID: providerA,
            contentType: "vod",
            currentIDs: ["a", "b", "c", "d"]
        )
        precondition(second.newItemIDs == ["d"], "Alleen het echt nieuwe item hoort als nieuw te tellen")
        precondition(second.firstSeenByID.count == 4)

        // 3. Storing/lege ophaalbeurt: de aanroeper roept dit bewust NIET aan,
        //    dus de snapshot verandert niet en niets wordt als "verwijderd" gezien.
        let untouched = store.currentFirstSeen(providerID: providerA, contentType: "vod")
        precondition(untouched.keys.sorted() == ["a", "b", "c", "d"], "Snapshot mag niet wijzigen zonder een geslaagde fetch")

        // 4. Een item dat verdwijnt uit een latere, WEL geslaagde, niet-lege
        //    ophaalbeurt wordt pas dan opgeruimd -- en duikt het later weer op,
        //    dan telt het opnieuw als "nieuw" (provider kan het echt opnieuw
        //    hebben toegevoegd).
        let third = await store.recordSuccessfulFetch(
            providerID: providerA,
            contentType: "vod",
            currentIDs: ["a", "b", "c"]
        )
        precondition(third.newItemIDs.isEmpty, "Verwijderen van een item mag geen 'nieuw' triggeren")
        precondition(third.firstSeenByID.count == 3, "'d' hoort na een geslaagde fetch zonder 'd' opgeruimd te zijn")

        let fourth = await store.recordSuccessfulFetch(
            providerID: providerA,
            contentType: "vod",
            currentIDs: ["a", "b", "c", "d"]
        )
        precondition(fourth.newItemIDs == ["d"], "Een teruggekeerd item telt opnieuw als nieuw")

        // 5. Providers en contentTypes staan volledig los van elkaar.
        let providerBFirst = await store.recordSuccessfulFetch(
            providerID: providerB,
            contentType: "vod",
            currentIDs: ["a"]
        )
        precondition(providerBFirst.newItemIDs.isEmpty, "Elke provider heeft zijn eigen baseline")

        let providerASeries = await store.recordSuccessfulFetch(
            providerID: providerA,
            contentType: "series",
            currentIDs: ["a"]
        )
        precondition(providerASeries.newItemIDs.isEmpty, "'vod' en 'series' delen geen snapshot, ook niet bij hetzelfde ID")

        // 6. Nieuw-venster.
        let now = Date()
        precondition(IPTVDiscoverySnapshotStore.isWithinNewWindow(now.addingTimeInterval(-1 * 24 * 60 * 60), now: now))
        precondition(!IPTVDiscoverySnapshotStore.isWithinNewWindow(now.addingTimeInterval(-20 * 24 * 60 * 60), now: now))

        // Opruimen na de test.
        IPTVDiskCache.remove(key: "discovery-snapshot-\(providerA.uuidString)-vod")
        IPTVDiskCache.remove(key: "discovery-snapshot-\(providerA.uuidString)-series")
        IPTVDiskCache.remove(key: "discovery-snapshot-\(providerB.uuidString)-vod")

        print("IPTV discovery checks passed: baseline, diff, outage-veiligheid, terugkerende items, provider/contentType-scheiding, nieuw-venster")
    }
}
