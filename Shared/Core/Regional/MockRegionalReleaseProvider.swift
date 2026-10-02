// MockRegionalReleaseProvider.swift — gedeeld (tvOS/iOS/iPadOS/macOS)
// Fase 2 ("ÉÉN PROVIDER VERTICAL SLICE"): tijdelijke, lokale testprovider die de volledige
// pijplijn (adapter → registry → repository → Home) end-to-end bewijst zonder een ongeverifieerde
// VRT/VTM/Play/Streamz-endpoint te gokken. Geen netwerkverkeer, geen scraping -- enkel plausibele
// testdata voor regio "BE-VL". Zodra de gebruiker een echte, bevestigde endpoint aanlevert, komt
// er een echte provider (bv. `VRTMaxRegionalReleaseProvider`) naast/in plaats van deze mock, via
// dezelfde `RegionalReleaseProvider`-architectuur -- geen enkele andere laag hoeft dan te wijzigen.
import Foundation

nonisolated struct MockRegionalReleaseProvider: RegionalReleaseProvider {
    let id = "mock.be-vl"
    let displayName = "Mock (BE-VL testdata)"
    let supportedRegions: Set<String> = [RegionalReleaseContext.defaultRegion]

    func releases(context: RegionalReleaseContext) async throws -> [RegionalReleaseEvent] {
        let now = Date()
        let calendar = Calendar.current

        func date(daysFromNow days: Int, hour: Int = 20, minute: Int = 40) -> Date {
            let base = calendar.date(byAdding: .day, value: days, to: now) ?? now
            return calendar.date(
                bySettingHour: hour, minute: minute, second: 0, of: base
            ) ?? base
        }

        return [
            RegionalReleaseEvent(
                id: "mock:newseries:1",
                providerID: id,
                channelID: "vrt1",
                region: context.region,
                countryCode: context.countryCode,
                languageCode: context.languageCode,
                title: "De Nieuwe Reeks",
                releaseType: .newSeries,
                releaseDate: date(daysFromNow: 0),
                airDate: date(daysFromNow: 0),
                season: 1,
                episode: 1,
                sourceConfidence: 1.0
            ),
            RegionalReleaseEvent(
                id: "mock:newseason:1",
                providerID: id,
                channelID: "vtm",
                region: context.region,
                countryCode: context.countryCode,
                languageCode: context.languageCode,
                title: "Thuis",
                releaseType: .newSeason,
                releaseDate: date(daysFromNow: -1),
                airDate: date(daysFromNow: -1, hour: 19, minute: 50),
                season: 32,
                sourceConfidence: 0.9
            ),
            RegionalReleaseEvent(
                id: "mock:premiere:1",
                providerID: id,
                channelID: "goplay",
                region: context.region,
                countryCode: context.countryCode,
                languageCode: context.languageCode,
                title: "Zomerhit",
                releaseType: .premiere,
                releaseDate: date(daysFromNow: 2),
                airDate: date(daysFromNow: 2, hour: 21, minute: 0),
                sourceConfidence: 0.8
            ),
            RegionalReleaseEvent(
                id: "mock:upcoming:1",
                providerID: id,
                channelID: "streamz",
                region: context.region,
                countryCode: context.countryCode,
                languageCode: context.languageCode,
                title: "Binnenkort op Streamz",
                releaseType: .upcomingPremiere,
                releaseDate: date(daysFromNow: 9),
                sourceConfidence: 0.6
            ),
            RegionalReleaseEvent(
                id: "mock:episode:1",
                providerID: id,
                channelID: "vrt1",
                region: context.region,
                countryCode: context.countryCode,
                languageCode: context.languageCode,
                title: "De Nieuwe Reeks",
                releaseType: .episode,
                releaseDate: date(daysFromNow: 7),
                airDate: date(daysFromNow: 7),
                season: 1,
                episode: 2,
                sourceConfidence: 1.0
            )
        ]
    }
}
