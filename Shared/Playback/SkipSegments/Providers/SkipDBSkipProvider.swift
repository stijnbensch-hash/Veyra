import Foundation

/// Tweede externe provider (spec §17-19/Fase 5): SkipDB
/// (https://skipdb.tv) -- achter dezelfde `VeyraSkipSegmentProvider`-
/// abstraction als `TheIntroDBSkipProvider`, dus geen Player-wijzigingen
/// nodig (spec §120).
///
/// Matcht uitsluitend op IMDb-id (spec §10: de provider bepaalt zelf welke
/// IDs hij ondersteunt). Zonder bruikbaar IMDb-id draagt deze provider
/// simpelweg niets bij -- dat is geen storing, dus geen throw, gewoon `[]`
/// zodat de resolver dit niet als "alle providers gefaald" ziet wanneer
/// alleen TheIntroDB (TMDB-matching) bruikbare data had.
struct SkipDBSkipProvider: VeyraSkipSegmentProvider {
    let id = "skipDB"
    // Lager dan TheIntroDB (50): voorgestelde default-volgorde uit de spec
    // (§28) is TheIntroDB vóór SkipDB. De resolver gebruikt priority vandaag
    // niet hard voor dedupe (die kiest op confidence), maar wel als signaal
    // voor toekomstige resolver-verfijning (Fase 7).
    let priority = 40

    func segments(for media: VeyraSkipMediaIdentity) async throws -> [VeyraSkipSegment] {
        guard let imdbID = Self.validIMDbID(media.imdbID) else { return [] }

        switch await SkipDBClient.shared.lookup(
            imdbID: imdbID,
            season: media.season,
            episode: media.episode,
            durationSeconds: media.duration
        ) {
        case .success(let segments): return segments
        case .failure: throw VeyraSkipSegmentProviderError.lookupFailed
        }
    }

    private static func validIMDbID(_ raw: String?) -> String? {
        guard let imdbID = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              imdbID.hasPrefix("tt"), imdbID.dropFirst(2).count >= 7,
              imdbID.dropFirst(2).allSatisfy(\.isNumber) else { return nil }
        return imdbID
    }
}
