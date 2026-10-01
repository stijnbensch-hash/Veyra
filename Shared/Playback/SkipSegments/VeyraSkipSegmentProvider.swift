import Foundation

/// Eén bron van skip-markers (TheIntroDB, later SkipDB, server-markers,
/// ...). De resolver bevraagt alle geregistreerde providers en voegt hun
/// resultaten samen -- een provider weet alleen van zijn eigen API, nooit
/// van de Player of van andere providers.
///
/// Een provider mag gooien bij een MISLUKTE opzoeking (timeout/429/5xx) --
/// onderscheid met een bevestigd leeg antwoord (geen markers bekend) is
/// precies de "error ≠ empty"-eis uit de audit (spec §119/Fase 4). De
/// resolver vangt elke provider apart op (`Result` per taak), dus één
/// falende bron laat de hele resolve niet mislukken (spec §83/84:
/// provider-isolatie) -- maar de store kan nu wél onderscheiden "echt geen
/// markers" van "kon het niet checken", en alleen het eerste cachen.
protocol VeyraSkipSegmentProvider: Sendable {
    var id: String { get }
    /// Hogere waarde = voorkeur bij gelijkwaardige/overlappende markers.
    /// De resolver gebruikt dit als uitgangspunt, niet als absolute regel.
    var priority: Int { get }

    func segments(for media: VeyraSkipMediaIdentity) async throws -> [VeyraSkipSegment]
}

/// Door een provider gegooid wanneer de onderliggende opzoeking mislukte
/// (geen geldig antwoord gekregen) -- nooit voor een bevestigd leeg
/// resultaat, dat blijft gewoon `[]` zonder te gooien.
enum VeyraSkipSegmentProviderError: Error {
    case lookupFailed
}
