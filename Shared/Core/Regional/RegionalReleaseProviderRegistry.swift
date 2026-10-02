// RegionalReleaseProviderRegistry.swift — gedeeld (tvOS/iOS/iPadOS/macOS)
// Fase 1 (spec §19): centrale registry van `RegionalReleaseProvider`-adapters. Leeg bij start --
// concrete bronnen (VRT/VTM/Play/Streamz) registreren zichzelf pas vanaf fase 2 (één provider
// end-to-end) / fase 12 (overige Belgische providers). `RegionalReleaseRepository` kent deze
// registry, nooit een providernaam rechtstreeks.
import Foundation

actor RegionalReleaseProviderRegistry {
    static let shared = RegionalReleaseProviderRegistry()

    private var providers: [String: RegionalReleaseProvider] = [:]

    private init() {}

    /// Idempotent: een tweede registratie met hetzelfde `id` vervangt de vorige (handig voor
    /// tests/previews die een mock-provider willen inpluggen).
    func register(_ provider: RegionalReleaseProvider) {
        providers[provider.id] = provider
    }

    func unregister(id: String) {
        providers[id] = nil
    }

    /// Enkel providers die `region` in hun `supportedRegions` hebben (spec §19/§24) -- een lege
    /// registry (fase 1, nog geen concrete bron aangesloten) geeft gewoon `[]` terug.
    func providers(for region: String) -> [RegionalReleaseProvider] {
        providers.values
            .filter { $0.supportedRegions.contains(region) }
            .sorted { $0.id < $1.id }
    }

    func allProviders() -> [RegionalReleaseProvider] {
        providers.values.sorted { $0.id < $1.id }
    }
}
