import Foundation

/// Artwork-engine-spec §72/§73: diagnostics horen NIET in de normale UI (geen source-label op
/// Home, §72) maar wel in een apart diagnostics-scherm onder Instellingen → Metadata. Puur
/// in-memory ringbuffer -- nooit gepersisteerd (geen secrets/tokens, en dit hoort niet via
/// VeyraHub of UserDefaults mee te gaan, §73's "geen secrets/tokens loggen"): elke sessie start
/// leeg, en het is bewust NIET bedoeld als permanente geschiedenis.
struct MetadataDiagnosticsEvent: Identifiable {
    enum Kind: String {
        case metadata = "Metadata"
        case artwork = "Artwork"
    }

    let id = UUID()
    let timestamp = Date()
    let kind: Kind
    /// tmdbID/imdbID van het item -- nooit de titel, dit is diagnostiek, geen leesbare lijst.
    let canonicalID: String
    let sourceSelected: String
    let sourceActuallyUsed: String
    let fallbackUsed: Bool
    let cacheHit: Bool
    let addonID: String?
    let candidateID: String?
    let language: String?
    let durationMs: Int
}

actor MetadataDiagnosticsRecorder {
    static let shared = MetadataDiagnosticsRecorder()

    private static let capacity = 200
    private var events: [MetadataDiagnosticsEvent] = []

    private init() {}

    func record(_ event: MetadataDiagnosticsEvent) {
        events.append(event)
        if events.count > Self.capacity {
            events.removeFirst(events.count - Self.capacity)
        }
    }

    /// Meest recente eerst.
    func recent() -> [MetadataDiagnosticsEvent] {
        events.reversed()
    }

    func clear() {
        events.removeAll()
    }
}

extension MetadataDiagnosticsRecorder {
    /// Gemakshelper zodat `MetadataRepository` (actor) en `ArtworkResolver` (andere actor) geen
    /// eigen duplicaat van de duur-/event-opbouw moeten bijhouden.
    static func log(
        kind: MetadataDiagnosticsEvent.Kind,
        canonicalID: String,
        sourceSelected: String,
        sourceActuallyUsed: String,
        fallbackUsed: Bool,
        cacheHit: Bool,
        addonID: String? = nil,
        candidateID: String? = nil,
        language: String? = nil,
        since start: Date
    ) async {
        let durationMs = Int(Date().timeIntervalSince(start) * 1000)
        await shared.record(MetadataDiagnosticsEvent(
            kind: kind, canonicalID: canonicalID, sourceSelected: sourceSelected,
            sourceActuallyUsed: sourceActuallyUsed, fallbackUsed: fallbackUsed, cacheHit: cacheHit,
            addonID: addonID, candidateID: candidateID, language: language, durationMs: durationMs
        ))
    }
}
