// VeyraBentoHeroModel.swift — gedeeld door de tvOS- en iOS/macOS-hero
// Voeg dit bestand toe aan alle targets. De views zelf staan achter #if os(...).

import Foundation

// MARK: - Model

nonisolated struct HeroMoment: Identifiable, Equatable {
    let id: String
    let label: String          // "NU", "NU LIVE", "STRAKS", "HERVAT", "AFSPELEN"
    let title: String          // programmanaam of "S2E4 · Titel"
    let metaLine: String       // altijd zichtbaar: "S2E4 · nog 23 min"
    let backdropURL: URL?
    let progress: Double?      // 0...1, nil = geen voortgang (bv. "straks")
    let isLive: Bool
    let runtimeText: String?   // "2u 14m"
    let badges: [String]       // ["4K", "Dolby Vision", "3 bronnen klaar"]
}

nonisolated struct HeroContent {
    let logoURL: URL?
    let fallbackTitle: String
    let moments: [HeroMoment]  // 1 (film / sport) of 2 (nu + straks)
}

// MARK: - Film-variant: één moment, hervatten of starten

nonisolated extension HeroContent {
    /// Film: één moment. Met voortgang -> "HERVAT" + "nog X min", anders "AFSPELEN".
    static func movie(
        id: String,
        title: String,
        logoURL: URL?,
        backdropURL: URL?,
        runtimeMinutes: Int,
        watchedMinutes: Int?,
        badges: [String]
    ) -> HeroContent {
        let watched = watchedMinutes ?? 0
        let resuming = watched > 0 && watched < runtimeMinutes
        let runtime = formatRuntime(runtimeMinutes)

        let moment = HeroMoment(
            id: id,
            label: resuming ? "HERVAT" : "AFSPELEN",
            title: title,
            metaLine: resuming ? "\(runtime) · nog \(runtimeMinutes - watched) min" : runtime,
            backdropURL: backdropURL,
            progress: resuming ? Double(watched) / Double(runtimeMinutes) : nil,
            isLive: false,
            runtimeText: runtime,
            badges: badges
        )
        return HeroContent(logoURL: logoURL, fallbackTitle: title, moments: [moment])
    }
}

private nonisolated func formatRuntime(_ minutes: Int) -> String {
    minutes >= 60 ? "\(minutes / 60)u \(minutes % 60)m" : "\(minutes) min"
}

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

// MARK: - Voorbeelddata voor previews

#if DEBUG
nonisolated extension HeroContent {
    static let previewSeries = HeroContent(
        logoURL: nil,
        fallbackTitle: "Severance",
        moments: [
            HeroMoment(id: "s2e4", label: "NU", title: "S2E4 · Woe's Hollow",
                       metaLine: "S2E4 · nog 23 min", backdropURL: nil, progress: 0.46,
                       isLive: false, runtimeText: "47 min",
                       badges: ["4K", "Dolby Vision", "3 bronnen klaar"]),
            HeroMoment(id: "s2e5", label: "STRAKS", title: "S2E5 · Trojan's Horse",
                       metaLine: "S2E5 · volgende aflevering", backdropURL: nil, progress: nil,
                       isLive: false, runtimeText: "52 min",
                       badges: ["4K", "2 bronnen klaar"])
        ]
    )

    static let previewLive = HeroContent(
        logoURL: nil,
        fallbackTitle: "Één",
        moments: [
            HeroMoment(id: "nu", label: "NU LIVE", title: "Het Journaal",
                       metaLine: "Live · nog 12 min", backdropURL: nil, progress: 0.8,
                       isLive: true, runtimeText: nil, badges: ["HD", "Bron stabiel"]),
            HeroMoment(id: "straks", label: "STRAKS", title: "Thuis",
                       metaLine: "Begint om 19:00", backdropURL: nil, progress: nil,
                       isLive: false, runtimeText: nil, badges: ["HD"])
        ]
    )

    static let previewMovie = HeroContent.movie(
        id: "dune2", title: "Dune: Part Two", logoURL: nil, backdropURL: nil,
        runtimeMinutes: 166, watchedMinutes: 95,
        badges: ["4K", "Dolby Vision", "Atmos"]
    )

    static let previewMovieFresh = HeroContent.movie(
        id: "dune2-fresh", title: "Dune: Part Two", logoURL: nil, backdropURL: nil,
        runtimeMinutes: 166, watchedMinutes: nil,
        badges: ["4K", "2 bronnen klaar"]
    )
}
#endif
