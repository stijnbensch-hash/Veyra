import Foundation

/// Haalt TMDB's "clearlogo" (transparante titel-logo-afbeelding) op voor
/// een film of serie, voor gebruik i.p.v. een platte teksttitel op de
/// detailpagina (`VeyraClearLogo`).
enum ClearLogoService {
    static func logoURL(for item: MediaItem) async -> URL? {
        guard let tmdbID = item.tmdbID, let token = AppConfiguration.tmdbReadAccessToken else { return nil }

        // Fase 3 stap 4 (artwork-engine-spec §52/§53): taalvolgorde komt nu uit de instelbare
        // `ArtworkSettings` i.p.v. hier hardcoded "nl,en,null" te zijn (en elders, in
        // `VeyraTMDBArtwork`, inconsistent "en,nl,null" -- die aanroep loopt intussen ook via
        // deze service, zie `ArtworkResolver`).
        let settings = ArtworkSettingsStore().load()
        let primary = settings.language.rawValue
        let fallback = settings.fallbackLanguage.rawValue

        let path = item.type == .movie ? "/3/movie/\(tmdbID)/images" : "/3/tv/\(tmdbID)/images"
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.themoviedb.org"
        components.path = path
        // Logo's zonder taal ("null") zijn meestal de eigenlijke
        // studio-logo-afbeelding zonder tekst-overlay in een andere taal --
        // samen met de voorkeurs-/terugvaltaal dekt dit verreweg de meeste titels.
        components.queryItems = [URLQueryItem(name: "include_image_language", value: "\(primary),\(fallback),null")]

        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode),
              let decoded = try? JSONDecoder().decode(TMDBImagesResponse.self, from: data)
        else { return nil }

        let logos = decoded.logos
        let best = logos.first { $0.iso6391 == primary }
            ?? logos.first { $0.iso6391 == fallback }
            ?? logos.first { $0.iso6391 == nil }
            ?? logos.first

        guard let filePath = best?.filePath else { return nil }
        return TMDBImageURLBuilder.logo(filePath)
    }
}

private struct TMDBImagesResponse: Decodable {
    let logos: [TMDBImage]
}

private struct TMDBImage: Decodable {
    let filePath: String
    let iso6391: String?

    enum CodingKeys: String, CodingKey {
        case filePath = "file_path"
        case iso6391 = "iso_639_1"
    }
}
