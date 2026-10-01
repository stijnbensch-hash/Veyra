import Foundation

/// Player-facing ingang voor skip-segmenten. Dit is het ENIGE type dat de
/// Player kent -- geen `IntroDBClient`, geen providers (spec §53/129: "De
/// Player mag niet weten waar een marker vandaan komt").
///
/// Cache-first + single-flight: als Episode Detail, Player en Next-Up
/// tegelijk dezelfde aflevering bevragen, draait er maar 1 resolve-task
/// (spec §32/33).
actor VeyraSkipSegmentStore {
    static let shared = VeyraSkipSegmentStore()

    private struct CachedResult {
        let segments: [VeyraSkipSegment]
        let fetchedAt: Date
    }

    /// Positieve cache lang genoeg: intro-/aftitelingstijden veranderen
    /// zelden (spec §35). In-memory, net als `IntroDBClient`'s eigen cache
    /// -- reset bij elke app-herstart, geen persistente opslag nodig voor
    /// deze eerste versie (spec §90: "vermijd onnodige dubbele
    /// complexiteit").
    private static let cacheTTL: TimeInterval = 6 * 3600

    private let resolver: VeyraSkipSegmentResolver
    private var cache: [VeyraSkipMediaIdentity: CachedResult] = [:]
    private var inFlight: [VeyraSkipMediaIdentity: Task<VeyraSkipSegmentResolver.ResolveOutcome, Never>] = [:]

    init(resolver: VeyraSkipSegmentResolver = .shared) {
        self.resolver = resolver
    }

    func segments(for media: VeyraSkipMediaIdentity) async -> [VeyraSkipSegment] {
        guard media.isResolvable else { return [] }

        if let cached = cache[media], Date().timeIntervalSince(cached.fetchedAt) < Self.cacheTTL {
            #if DEBUG
            print("[SkipSegments][Store] cache=hit segments=\(cached.segments.count)")
            #endif
            return cached.segments
        }

        if let existing = inFlight[media] {
            #if DEBUG
            print("[SkipSegments][Store] request coalesced (single-flight)")
            #endif
            switch await existing.value {
            case .success(let segments): return segments
            case .allProvidersFailed: return []
            }
        }

        let resolver = self.resolver
        let task = Task<VeyraSkipSegmentResolver.ResolveOutcome, Never> {
            await resolver.resolve(media: media)
        }
        inFlight[media] = task
        let outcome = await task.value
        inFlight[media] = nil

        // Audit P0 (Fase 4): alleen een bevestigd resultaat (ook leeg) cachen.
        // Bij een storing (`.allProvidersFailed`) niets in `cache` zetten, zodat
        // de volgende aanroep -- of de volgende afspeling -- het opnieuw
        // probeert in plaats van tot 6 uur lang geen skip-knop te tonen.
        switch outcome {
        case .success(let segments):
            cache[media] = CachedResult(segments: segments, fetchedAt: Date())
            return segments
        case .allProvidersFailed:
            return []
        }
    }

    /// Lage-prioriteit vooraf ophalen (bv. de volgende aflevering bij
    /// autoplay, spec §41) -- zelfde pad, het resultaat belandt gewoon
    /// alvast in de cache zodat een latere `segments(for:)`-aanroep meteen
    /// een cache-hit is.
    func prefetch(_ media: VeyraSkipMediaIdentity) {
        guard media.isResolvable, cache[media] == nil, inFlight[media] == nil else { return }
        Task { _ = await segments(for: media) }
    }
}
