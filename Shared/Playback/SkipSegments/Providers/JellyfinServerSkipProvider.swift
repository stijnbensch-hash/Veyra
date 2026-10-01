import Foundation

/// Server-marker provider voor een genuine, direct verbonden Jellyfin-
/// server (spec §20-22/Fase 6): bevraagt Jellyfin's officiële Media
/// Segments API voor het EXACTE afgespeelde item -- betrouwbaarder dan een
/// algemene externe database wanneer beschikbaar (spec §22).
///
/// Draagt niets bij wanneer de huidige bron geen genuine Jellyfin-server-
/// item is (addon/IPTV/VeyraHub zonder deze metadata) -- dat is geen
/// storing, dus geen throw, gewoon `[]`. Alleen een mislukte opzoeking
/// (timeout/5xx/ongeldig antwoord) telt als storing; een server zonder de
/// Media Segments-plugin antwoordt met 404, wat `JellyfinService` al als
/// bevestigd leeg behandelt (zie daar).
struct JellyfinServerSkipProvider: VeyraSkipSegmentProvider {
    let id = "jellyfinServer"
    // Hoogste priority: exacte server/bestand-marker staat bovenaan de
    // voorgestelde voorkeursvolgorde (spec §28), en krijgt ook de hoogste
    // confidence (spec §52: "exact server marker -> very high") zodat de
    // resolver 'm automatisch verkiest boven een externe-database-marker
    // bij overlap (dedupe sorteert op confidence).
    let priority = 100

    func segments(for media: VeyraSkipMediaIdentity) async throws -> [VeyraSkipSegment] {
        guard let context = media.jellyfinContext else { return [] }

        do {
            let raw = try await JellyfinService(account: context.account)
                .mediaSegments(itemID: context.itemID)
            return Self.map(raw)
        } catch {
            throw VeyraSkipSegmentProviderError.lookupFailed
        }
    }

    private static func map(_ raw: [JellyfinMediaSegment]) -> [VeyraSkipSegment] {
        raw.compactMap { segment -> VeyraSkipSegment? in
            let type: VeyraSkipSegmentType
            switch segment.type {
            case .intro: type = .intro
            case .recap: type = .recap
            case .outro: type = .credits
            case .preview: type = .preview
            case .commercial: type = .commercial
            // Onbekend/ongeclassificeerd segmenttype -- niet gokken naar
            // welk Veyra-type dit zou moeten zijn (spec §26: geen
            // agressieve heuristiek zonder bewijs).
            case .unknown: return nil
            }

            let start = segment.startSeconds
            let end = segment.endSeconds
            guard end > start else { return nil }

            return VeyraSkipSegment(
                id: "jellyfin-\(type.rawValue)-\(Int(start))-\(Int(end))",
                type: type,
                start: start,
                end: end,
                source: .serverMarker,
                confidence: 0.95
            )
        }
    }
}
