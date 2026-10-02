// RegionalReleaseProvider.swift — gedeeld (tvOS/iOS/iPadOS/macOS)
// Fase 1 (spec §19): registry/adapter-abstractie voor regionale releasebronnen (VRT, VTM, Play,
// Streamz, en later niet-Belgische bronnen) -- i.p.v. `if country == "BE" { loadVRT() }` ergens
// hardcoded. Elke concrete bron (fase 2/12) implementeert dit protocol en meldt zich aan bij
// `RegionalReleaseProviderRegistry`; de core (`RegionalReleaseRepository`) kent geen enkele
// providernaam.
import Foundation

protocol RegionalReleaseProvider: Sendable {
    /// Stabiele, lage-case identifier (bv. "vrt", "vtm", "play", "streamz") -- gebruikt als
    /// `RegionalReleaseEvent.providerID` en als dedupe-/instellingensleutel. Nooit een
    /// weergavenaam (die hoort in `displayName`, spec §74: localization-ready).
    var id: String { get }
    var displayName: String { get }

    /// ISO-regiocodes (spec §20: bv. "BE-VL") waarvoor deze bron relevant is -- bepaalt welke
    /// providers `RegionalReleaseProviderRegistry.providers(for:)` teruggeeft voor een gegeven
    /// `RegionalReleaseContext.region`. Een gebruiker mag later bewust providers buiten zijn eigen
    /// regio toevoegen (spec §24) -- dat is een registratiekeuze, geen beperking van dit protocol.
    var supportedRegions: Set<String> { get }

    /// Haalt de releases op binnen `context.windowStart...windowDays`. Mag `throw`en -- de
    /// aanroeper (`RegionalReleaseRepository`) isoleert fouten per provider (spec §21: "één
    /// provider failure mag andere providers niet breken").
    func releases(context: RegionalReleaseContext) async throws -> [RegionalReleaseEvent]
}
