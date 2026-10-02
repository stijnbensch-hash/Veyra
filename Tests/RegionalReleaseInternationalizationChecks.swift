import Foundation

/// Fase 13 ("INTERNATIONALISATIE", spec §19/§24/§93): bewijst dat de Regional Releases-
/// architectuur een tweede, niet-Belgische regio kan bedienen zonder dat de registry of de
/// repository zelf ook maar één regel Belgische logica bevat. `DummyGermanProvider` hieronder is
/// een fictieve Duitse bron, enkel voor deze check -- nooit bij app-opstart geregistreerd (net
/// zoals `MockRegionalReleaseProvider` zelf enkel een tijdelijke BE-VL-testbron is, fase 2).
private struct DummyGermanProvider: RegionalReleaseProvider {
    let id = "mock.de"
    let displayName = "Mock (DE testdata)"
    let supportedRegions: Set<String> = ["DE"]

    func releases(context: RegionalReleaseContext) async throws -> [RegionalReleaseEvent] {
        // Geen enkele Belgische aanname (kanaal, taal, providernaam) -- enkel wat de generieke
        // `RegionalReleaseContext` meegeeft, exact zoals `MockRegionalReleaseProvider` dat voor
        // BE-VL doet.
        precondition(context.region == "DE", "Provider mag enkel voor zijn eigen regio bevraagd worden")
        return [
            RegionalReleaseEvent(
                id: "de-mock:newseries:1",
                providerID: id,
                channelID: "ard",
                region: context.region,
                countryCode: context.countryCode,
                languageCode: context.languageCode,
                title: "Neue Deutsche Serie",
                releaseType: .newSeries,
                releaseDate: context.windowStart
            )
        ]
    }
}

@main
struct RegionalReleaseInternationalizationChecks {
    static func main() async throws {
        let registry = RegionalReleaseProviderRegistry.shared

        let belgian = MockRegionalReleaseProvider()
        let german = DummyGermanProvider()
        await registry.register(belgian)
        await registry.register(german)

        // Spec §19: `providers(for:)` filtert uitsluitend op `supportedRegions` -- geen
        // `if country == "BE"`-achtige tak in de registry zelf.
        let beProviders = await registry.providers(for: RegionalReleaseContext.defaultRegion)
        precondition(beProviders.contains { $0.id == belgian.id }, "BE-VL-provider moet zichzelf vinden voor BE-VL")
        precondition(!beProviders.contains { $0.id == german.id }, "Duitse provider hoort niet mee in een BE-VL-resultaat")

        let deProviders = await registry.providers(for: "DE")
        precondition(deProviders.contains { $0.id == german.id }, "Duitse provider moet zichzelf vinden voor regio DE")
        precondition(!deProviders.contains { $0.id == belgian.id }, "BE-VL-provider hoort niet mee in een DE-resultaat")

        // Spec §24: regio is een default/filter, geen gevangenis -- eenzelfde registry bedient
        // meerdere regio's naast elkaar zonder dat providers van elkaar weten.
        let deContext = RegionalReleaseContext(region: "DE", countryCode: "DE", languageCode: "de")
        let deEvents = try await german.releases(context: deContext)
        precondition(deEvents.count == 1 && deEvents[0].region == "DE",
                     "Duitse bron levert eigen regio-gegevens via exact hetzelfde protocol als BE-VL")
        precondition(deEvents[0].releaseType.homePriority == 0,
                     "Dezelfde RegionalReleaseType-Home-prioriteit (spec §27) geldt ongeacht regio")

        let beEvents = try await belgian.releases(context: .defaultBelgiumFlanders())
        precondition(beEvents.allSatisfy { $0.region == RegionalReleaseContext.defaultRegion },
                     "BE-VL-mock blijft ongewijzigd werken naast de nieuwe Duitse bron")

        await registry.unregister(id: belgian.id)
        await registry.unregister(id: german.id)
        let empty = await registry.providers(for: "DE")
        precondition(empty.isEmpty, "unregister moet werken, ongeacht regio")

        print("Regional release internationalization checks passed: registry/provider-abstractie bedient BE-VL en DE identiek, zonder regio-specifieke logica in registry/repository")
    }
}
