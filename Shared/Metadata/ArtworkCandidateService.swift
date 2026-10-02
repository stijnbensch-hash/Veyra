import Foundation

/// Eén keuzemogelijkheid in de artwork-picker (§33/§57) -- alleen gevuld met wat TMDB's
/// `/images` daadwerkelijk teruggeeft voor deze titel (geen candidate verzonnen). Enkel geladen
/// wanneer de gebruiker de picker effectief opent (§68: "niet standaard alle alternatieven
/// downloaden").
struct ArtworkCandidate: Identifiable, Hashable {
    let type: VeyraArtworkType
    let providerPath: String
    let language: String?
    let voteAverage: Double
    let url: URL

    var id: String { "\(type.rawValue):\(providerPath)" }

    var override: VeyraArtworkOverride {
        VeyraArtworkOverride(type: type, source: .tmdb, providerPath: providerPath, language: language)
    }
}

enum ArtworkCandidateService {
    private struct Image: Decodable {
        let file_path: String
        let iso_639_1: String?
        let vote_average: Double
    }

    private struct Images: Decodable {
        let backdrops: [Image]
        let posters: [Image]
        let logos: [Image]
    }

    /// Haalt alle logo/poster/backdrop-candidates van TMDB op voor deze titel, hoogste score
    /// eerst. Geeft een leeg resultaat als er geen TMDB-ID is of de aanvraag mislukt -- de
    /// picker toont dan gewoon "geen alternatieven gevonden" i.p.v. een kapot scherm.
    static func candidates(for item: MediaItem) async -> [ArtworkCandidate] {
        guard let tmdbID = item.tmdbID, let token = AppConfiguration.tmdbReadAccessToken else { return [] }

        let path = item.type == .movie ? "movie" : "tv"
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.themoviedb.org"
        components.path = "/3/\(path)/\(tmdbID)/images"
        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let decoded = try? JSONDecoder().decode(Images.self, from: data)
        else { return [] }

        func mapped(_ images: [Image], type: VeyraArtworkType) -> [ArtworkCandidate] {
            images.sorted { $0.vote_average > $1.vote_average }.compactMap { image in
                let builtURL: URL?
                switch type {
                case .clearLogo: builtURL = TMDBImageURLBuilder.logo(image.file_path)
                case .poster: builtURL = TMDBImageURLBuilder.poster(image.file_path)
                case .backdrop: builtURL = TMDBImageURLBuilder.backdrop(image.file_path)
                }
                guard let builtURL else { return nil }
                return ArtworkCandidate(
                    type: type, providerPath: image.file_path, language: image.iso_639_1,
                    voteAverage: image.vote_average, url: builtURL
                )
            }
        }

        return mapped(decoded.logos, type: .clearLogo)
            + mapped(decoded.posters, type: .poster)
            + mapped(decoded.backdrops, type: .backdrop)
    }
}
