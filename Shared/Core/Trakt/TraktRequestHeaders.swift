import Foundation

/// Gecentraliseerde basisheaders voor élke Trakt-aanroep. Voorheen zette zowel
/// `TraktClient.send(...)` als `TraktHomeAPI.send(...)` (zie `VeyraBentoTrakt.swift`,
/// de aparte datapaal voor Home) deze headers onafhankelijk van elkaar -- zelfde
/// waarden, twee keer uitgeschreven, en zonder `User-Agent` (spec §26-27). Beide
/// clients roepen nu `apply(to:clientID:accessToken:)` aan i.p.v. losse
/// `setValue(...)`-regels.
nonisolated enum TraktRequestHeaders {
    /// "Veyra/<versie> (tvOS)" / "(iOS)" / "(macOS)" -- app-versie uit het bundle,
    /// platform via compile-time check (geen runtime UIDevice-afhankelijkheid nodig).
    static let userAgent: String = {
        let version = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "?"
        #if os(tvOS)
        let platform = "tvOS"
        #elseif os(macOS)
        let platform = "macOS"
        #else
        let platform = "iOS"
        #endif
        return "Veyra/\(version) (\(platform))"
    }()

    static func apply(to request: inout URLRequest, clientID: String, accessToken: String? = nil) {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("2", forHTTPHeaderField: "trakt-api-version")
        request.setValue(clientID, forHTTPHeaderField: "trakt-api-key")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
    }
}
