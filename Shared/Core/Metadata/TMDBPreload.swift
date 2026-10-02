// TMDBPreload.swift — gedeeld (tvOS/iOS/iPadOS/macOS)
// Fase 4 ("VEYRA — TMDB PERFORMANCE & CACHING REFACTOR" spec §13/§15/§18/§19:
// append_to_response + progressive detail loading). Drie toestanden, niet twee -- een gewone
// Optional kan niet onderscheiden tussen "deze aanroeper doet niet aan preloading, haal het dus
// gewoon zelf op" (`.none`, het bestaande gedrag voor elke niet-aangepaste aanroeper) en "een
// aanroeper IS een gecombineerde aanvraag aan het doen, wacht daar nog even op" (`.pending`,
// voorkomt dat de component zelf al een eigen aanvraag start terwijl het gecombineerde resultaat
// een render-cyclus later toch nog komt).
enum TMDBPreload<Value> {
    /// Geen enkele aanroeper geeft dit mee -- component haalt het zelf op, zoals voorheen.
    case none
    /// Een aanroeper is bezig met een gecombineerde aanvraag -- nog niet zelf ophalen.
    case pending
    /// Resultaat van de gecombineerde aanvraag (mag zelf ook `nil`/leeg zijn -- "bevestigd
    /// afwezig", niet opnieuw proberen).
    case value(Value)

    /// Stabiele sleutel voor een `.task(id:)` -- enkel de overgang `pending` → `value` moet de
    /// task laten herstarten, de inhoud van `value` zelf niet (anders zou elke render opnieuw
    /// triggeren).
    var stageKey: String {
        switch self {
        case .none: return "none"
        case .pending: return "pending"
        case .value: return "value"
        }
    }
}
