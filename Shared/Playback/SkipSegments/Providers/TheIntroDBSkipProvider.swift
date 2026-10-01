import Foundation

/// Wrapt de bestaande `IntroDBClient` (cache, single-flight, error≠empty-
/// afhandeling zitten daar al, zie `Shared/Playback/IntroDBClient.swift`)
/// als `VeyraSkipSegmentProvider` -- mapt alleen `IntroDBSegments` naar het
/// uniforme Veyra-model. Geen herschrijving van `IntroDBClient` zelf.
struct TheIntroDBSkipProvider: VeyraSkipSegmentProvider {
    let id = "theIntroDB"
    let priority = 50

    func segments(for media: VeyraSkipMediaIdentity) async throws -> [VeyraSkipSegment] {
        switch await IntroDBClient.shared.lookup(
            tmdbID: media.tmdbID,
            imdbID: media.imdbID,
            season: media.season,
            episode: media.episode,
            durationSeconds: media.duration
        ) {
        case .success(let raw): return Self.map(raw)
        case .failure: throw VeyraSkipSegmentProviderError.lookupFailed
        }
    }

    private static func map(_ raw: IntroDBSegments) -> [VeyraSkipSegment] {
        var result: [VeyraSkipSegment] = []
        func append(_ segments: [IntroDBSegment], type: VeyraSkipSegmentType) {
            for (index, segment) in segments.enumerated() {
                result.append(VeyraSkipSegment(
                    id: "introdb-\(type.rawValue)-\(index)-\(segment.start ?? -1)-\(segment.end ?? -1)",
                    type: type,
                    start: segment.start,
                    end: segment.end,
                    source: .theIntroDB,
                    // TheIntroDB levert exacte, community-geverifieerde tijden zonder
                    // duration-matching; "high" i.p.v. "very high" (dat laatste is
                    // gereserveerd voor een exacte server/bestand-marker, spec §52).
                    confidence: 0.7
                ))
            }
        }
        append(raw.intros, type: .intro)
        append(raw.recaps, type: .recap)
        append(raw.creditsSegments, type: .credits)
        append(raw.previews, type: .preview)
        return result
    }
}
