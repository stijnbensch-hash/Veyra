import Foundation

/// Centrale resolver: bevraagt alle geregistreerde providers PARALLEL (spec
/// §29/31: niet serieel afwachten), valideert en dedupliceert de
/// resultaten, en levert precies ÉÉN `[VeyraSkipSegment]`-lijst terug.
/// `VeyraSkipSegmentStore`/Player kennen alleen dit resultaat, nooit de
/// providers zelf.
///
/// Met vandaag maar 1 geregistreerde provider (TheIntroDB) is dedupe/
/// validatie hier al aanwezig zodat een volgende provider (SkipDB,
/// server-markers) zonder herontwerp aan deze resolver toegevoegd kan
/// worden -- gewoon een extra item in `providers`.
actor VeyraSkipSegmentResolver {
    static let shared = VeyraSkipSegmentResolver()

    private let providers: [any VeyraSkipSegmentProvider]

    init(providers: [any VeyraSkipSegmentProvider] = [
        JellyfinServerSkipProvider(), TheIntroDBSkipProvider(), SkipDBSkipProvider(),
    ]) {
        self.providers = providers
    }

    /// `.allProvidersFailed` betekent: geen enkele provider kon een geldig
    /// antwoord geven (storing), NIET "alle providers zeggen geen markers" --
    /// dat laatste is gewoon `.success([])`. De store cachet alleen
    /// `.success`, zodat een storing bij de volgende afspeling opnieuw
    /// geprobeerd wordt in plaats van 6 uur lang "geen skip-knop" te tonen
    /// (spec §119, Fase 4 "error ≠ empty").
    enum ResolveOutcome {
        case success([VeyraSkipSegment])
        case allProvidersFailed
    }

    func resolve(media: VeyraSkipMediaIdentity) async -> ResolveOutcome {
        guard media.isResolvable else { return .success([]) }
        guard !providers.isEmpty else { return .success([]) }

        #if DEBUG
        print(
            "[SkipSegments] resolve tmdb=\(media.tmdbID.map(String.init) ?? "-")"
                + " imdb=\(media.imdbID ?? "-") season=\(media.season.map(String.init) ?? "-")"
                + " episode=\(media.episode.map(String.init) ?? "-")"
                + " duration=\(media.duration.map { Int($0) }.map(String.init) ?? "-")"
        )
        #endif

        // Per provider ook latency meenemen -- puur voor DEBUG-diagnostiek
        // (spec §73/125), geen functioneel gebruik.
        typealias ProviderOutcome = (id: String, latencyMs: Int, result: Result<[VeyraSkipSegment], Error>)
        let outcomes: [ProviderOutcome] = await withTaskGroup(of: ProviderOutcome.self) { group in
            for provider in providers {
                group.addTask {
                    let start = Date()
                    let result: Result<[VeyraSkipSegment], Error>
                    do { result = .success(try await provider.segments(for: media)) }
                    catch { result = .failure(error) }
                    let latencyMs = Int(Date().timeIntervalSince(start) * 1000)
                    return (provider.id, latencyMs, result)
                }
            }
            var all: [ProviderOutcome] = []
            for await outcome in group { all.append(outcome) }
            return all
        }

        var candidates: [VeyraSkipSegment] = []
        var sawSuccess = false
        for outcome in outcomes {
            #if DEBUG
            switch outcome.result {
            case .success(let segments):
                // Een latency van een paar ms wijst vrijwel altijd op een
                // provider-eigen cache-hit (bv. IntroDBClient's interne
                // cache) i.p.v. een echte netwerkaanroep -- alleen voor
                // DEBUG-inzicht, geen harde garantie (spec §73).
                let cacheHint = outcome.latencyMs < 5 ? "hit" : "miss"
                print(
                    "[SkipSegments][\(outcome.id)] cache=\(cacheHint)"
                        + " segments=\(segments.count) duration=\(outcome.latencyMs)ms"
                )
            case .failure:
                print("[SkipSegments][\(outcome.id)] lookupFailed duration=\(outcome.latencyMs)ms")
            }
            #endif
            if case .success(let segments) = outcome.result {
                sawSuccess = true
                candidates.append(contentsOf: segments)
            }
        }

        guard sawSuccess else {
            #if DEBUG
            print("[SkipSegments] allProvidersFailed")
            #endif
            return .allProvidersFailed
        }

        let validated = Self.validate(candidates, duration: media.duration)
        let resolved = Self.deduplicate(validated)
        #if DEBUG
        print("[SkipSegments] candidates=\(candidates.count) resolved=\(resolved.count)")
        #endif
        return .success(resolved)
    }

    // MARK: - Validatie (spec §43-46)

    private static func validate(_ segments: [VeyraSkipSegment], duration: TimeInterval?) -> [VeyraSkipSegment] {
        segments.filter { segment in
            if let start = segment.start, start < 0 { return false }
            if let start = segment.start, let end = segment.end, end <= start { return false }
            if let duration, duration.isFinite, duration > 0 {
                // Kleine tolerantie op het einde (spec §43): een marker-dataset kan
                // net een paar seconden afwijken van de daadwerkelijke bestandsduur.
                if let start = segment.start, start > duration { return false }
                if let end = segment.end, end > duration + 5 { return false }
            }
            return true
        }
    }

    // MARK: - Deduplicatie (spec §48-51)

    /// Segmenten van hetzelfde type die sterk overlappen tellen als dezelfde
    /// marker -- behoud de kandidaat met de hoogste confidence, niet een
    /// gemiddelde (spec §50). Segmenten die niet overlappen (bv. twee losse
    /// recaps) blijven allebei bestaan (spec §51). Bij gelijke confidence
    /// (zelden, maar mogelijk) beslist `sourcePriority` als tweede
    /// sorteersleutel -- geen simpele "provider A is altijd beter" regel
    /// (spec §27), maar wel een voorspelbare tiebreak volgens de
    /// voorgestelde default-volgorde (spec §28).
    private static func deduplicate(_ segments: [VeyraSkipSegment]) -> [VeyraSkipSegment] {
        var result: [VeyraSkipSegment] = []
        let ranked = segments.sorted { a, b in
            let confidenceA = a.confidence ?? 0, confidenceB = b.confidence ?? 0
            if confidenceA != confidenceB { return confidenceA > confidenceB }
            return sourcePriority(a.source) > sourcePriority(b.source)
        }
        for segment in ranked {
            let isDuplicate = result.contains {
                $0.type == segment.type && overlaps($0, segment)
            }
            if !isDuplicate { result.append(segment) }
        }
        return result
    }

    /// Voorgestelde default-voorkeursvolgorde (spec §28): exact server/
    /// bestand-marker > TheIntroDB > SkipDB > chapter-heuristiek. Dit
    /// bepaalt vandaag alleen de tiebreak bij gelijke confidence -- de
    /// eigenlijke dedupe-keuze blijft confidence-gedreven (spec §27:
    /// "resolver moet rekening houden met source reliability, duration
    /// match, media identity quality, segment validity", niet met een
    /// hardcoded provider-voorkeur als enige regel).
    private static func sourcePriority(_ source: VeyraSkipSegmentSource) -> Int {
        switch source {
        case .serverMarker: return 100
        case .theIntroDB: return 50
        case .skipDB: return 40
        case .chapter: return 10
        }
    }

    /// Overlapt met meer dan de helft van de kortste van de twee segmenten.
    private static func overlaps(_ a: VeyraSkipSegment, _ b: VeyraSkipSegment) -> Bool {
        let aStart = a.start ?? 0, aEnd = a.end ?? .greatestFiniteMagnitude
        let bStart = b.start ?? 0, bEnd = b.end ?? .greatestFiniteMagnitude
        let overlapStart = max(aStart, bStart)
        let overlapEnd = min(aEnd, bEnd)
        guard overlapEnd > overlapStart else { return false }
        let overlapLength = overlapEnd - overlapStart
        let shorter = min(aEnd - aStart, bEnd - bStart)
        guard shorter.isFinite, shorter > 0 else { return overlapLength > 0 }
        return overlapLength / shorter > 0.5
    }
}
