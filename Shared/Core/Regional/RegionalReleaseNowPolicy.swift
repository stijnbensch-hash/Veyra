// RegionalReleaseNowPolicy.swift — gedeeld (tvOS/iOS/iPadOS/macOS)
// Fase 5 ("VEYRA NOW" spec §7/§46): één centrale, herbruikbare policy die bepaalt OF en met welke
// prioriteit een regionale release op dit moment "Now"-waardig is -- spec §46: "Maak één centrale
// policy/resolver. Niet verspreiden over SwiftUI-views." Puur functies, geen UI/state, zodat zowel
// tvOS (`VeyraBentoHome.swift`) als een latere iOS-aansluiting (`VeyraBentoHomeIOS.swift`)
// dezelfde regels gebruiken i.p.v. elk hun eigen interpretatie.
import Foundation

nonisolated enum RegionalReleaseNowPolicy {
    /// Spec §7: "Vandaag nieuwe serie"/"Première vanavond"/"Net beschikbaar" zijn sterke
    /// kandidaten; een release van een paar dagen geleden kan nog kandidaat zijn met lagere
    /// prioriteit; iets dat al langer geleden verscheen ("Twee weken oude release") normaal niet
    /// meer -- die blijft dan gewoon in "Nieuw van hier" staan (spec §39/§44), nooit hier
    /// verwijderd. `nil` == geen Veyra Now-kandidaat.
    static func priority(for event: RegionalReleaseEvent, now: Date) -> Double? {
        // Spec §12: individuele afleveringen overspoelen "Nieuw van hier" al niet met S01E02/E03
        // -- diezelfde terughoudendheid geldt hier des te meer. Veyra Now blijft voor nieuwe
        // series/seizoenen/premières, geen losse episodes.
        guard event.releaseType != .episode else { return nil }

        let calendar = Calendar.current
        let referenceDate = event.airDate ?? event.releaseDate
        let daysAgo = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: referenceDate),
            to: calendar.startOfDay(for: now)
        ).day ?? 0

        // Een `upcomingPremiere`/`premiere` kan nog in de toekomst liggen (bv. "vanavond 20:40"
        // of "over 3 dagen") -- vandaag/vanavond telt sterk mee, verder weg nog niet als kandidaat.
        if daysAgo < 0 {
            guard event.releaseType == .upcomingPremiere || event.releaseType == .premiere else { return nil }
            return daysAgo >= -1 ? 80 : nil
        }

        switch daysAgo {
        case 0: return 80       // "Vandaag"/"Première vanavond"/"Net beschikbaar"
        case 1...3: return 55   // "kan nog kandidaat zijn, maar lagere prioriteit"
        default: return nil     // "Twee weken oud: normaal alleen Nieuw van hier, niet Veyra Now"
        }
    }

    static func isNowWorthy(_ event: RegionalReleaseEvent, now: Date) -> Bool {
        priority(for: event, now: now) != nil
    }
}
