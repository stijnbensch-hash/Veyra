import Foundation

/// Eén item van TMDB's `/movie/{id}/videos` of `/tv/{id}/videos`-endpoint.
/// TMDB host zelf geen videobestanden: `key` is een video-ID op het externe
/// platform in `site` (meestal "YouTube").
struct TMDBVideo: Decodable, Identifiable, Hashable {
    let id: String
    let key: String
    let name: String
    let site: String
    let type: String
    let official: Bool
}

struct TMDBVideosResponse: Decodable {
    let results: [TMDBVideo]
}

extension Array where Element == TMDBVideo {
    /// Kiest de beste YouTube-trailer uit de videolijst: een officiële
    /// trailer heeft voorrang, dan een niet-officiële trailer, dan een
    /// teaser, en anders de eerste beschikbare YouTube-video.
    var bestTrailerKey: String? {
        let youtube = filter { $0.site == "YouTube" }
        if let officialTrailer = youtube.first(where: { $0.type == "Trailer" && $0.official }) {
            return officialTrailer.key
        }
        if let trailer = youtube.first(where: { $0.type == "Trailer" }) {
            return trailer.key
        }
        if let teaser = youtube.first(where: { $0.type == "Teaser" }) {
            return teaser.key
        }
        return youtube.first?.key
    }
}
