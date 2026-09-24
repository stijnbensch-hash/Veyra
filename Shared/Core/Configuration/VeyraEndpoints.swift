import Foundation

/// Centrale plek voor de basisadressen van externe gegevensbronnen.
///
/// Standaard praat de app rechtstreeks met de bron. Zet je (later) één gateway neer, bijvoorbeeld VeyraHub die de
/// aanvragen doorstuurt, dan vul je alleen `veyra.gateway.url` in en alle bronnen lopen erlangs, zonder dat de app
/// opnieuw gebouwd hoeft te worden. Verwacht pad-schema op de gateway: `<gateway>/tmdb/3/...`, `<gateway>/fanart/v3/...`,
/// `<gateway>/sports/...`.
nonisolated enum VeyraEndpoints {
    static let gatewayKey = "veyra.gateway.url"

    /// Gateway-adres zonder slot-slash, of nil = rechtstreeks.
    static var gateway: String? {
        guard let raw = UserDefaults.standard.string(forKey: gatewayKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty,
              raw.lowercased().hasPrefix("https://") else { return nil }
        return raw.hasSuffix("/") ? String(raw.dropLast()) : raw
    }

    /// TMDB API v3 (zonder slot-slash).
    static var tmdb: String { gateway.map { $0 + "/tmdb/3" } ?? "https://api.themoviedb.org/3" }

    /// fanart.tv v3.
    static var fanart: String { gateway.map { $0 + "/fanart/v3" } ?? "https://webservice.fanart.tv/v3" }

    /// Sportscoreboards (ESPN-schema: `<basis>/<sport>/<competitie>/scoreboard`).
    static var sports: String { gateway.map { $0 + "/sports" } ?? "https://site.api.espn.com/apis/site/v2/sports" }
}
