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
    /// Alleen trailers en teasers met een bruikbare YouTube-sleutel komen in
    /// de trailerssectie. Een willekeurige clip mag daar niet als trailer staan.
    var bestTrailer: TMDBVideo? {
        let youtube = filter {
            $0.site.caseInsensitiveCompare("YouTube") == .orderedSame
                && !$0.key.isEmpty
                && $0.key.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil
        }
        return youtube.first(where: { $0.type == "Trailer" && $0.official })
            ?? youtube.first(where: { $0.type == "Trailer" })
            ?? youtube.first(where: { $0.type == "Teaser" })
    }
}
