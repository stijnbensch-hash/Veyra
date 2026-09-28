// VeyraBentoHeroModel.swift — gedeeld door de tvOS- en iOS/macOS-catalogusclearlogo-code
// Voeg dit bestand toe aan alle targets.
//
// Bevatte vroeger ook `HeroContent`/`HeroMoment` (voor een losse Bento-hero-view met
// "NU/STRAKS"-momenten en badges), maar die view (`VeyraHeroView` in
// `VeyraBentoHero.swift`/`VeyraBentoHeroIOS.swift`) werd nergens meer aangeroepen --
// vervangen door `VeyraHeroSpotlightView`. Opgeruimd; alleen de clearlogo-hulpfuncties
// hieronder worden nog écht gebruikt (VeyraBentoAdapters.swift, VeyraBentoTrakt.swift).

import Foundation

// MARK: - TMDB clearlogo kiezen (NL -> EN -> taalloos, hoogste score)

nonisolated struct TMDBLogo: Decodable {
    let file_path: String
    let iso_639_1: String?
    let vote_average: Double
}

nonisolated func pickClearlogoURL(from logos: [TMDBLogo], size: String = "w500") -> URL? {
    for lang in ["nl", "en", nil] as [String?] {
        let group = logos.filter { $0.iso_639_1 == lang }
        if let best = group.max(by: { $0.vote_average < $1.vote_average }) {
            return URL(string: "https://image.tmdb.org/t/p/\(size)\(best.file_path)")
        }
    }
    return nil
}
