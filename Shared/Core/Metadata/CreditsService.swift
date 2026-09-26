import Foundation

/// Rolverdeling (cast + crew) van een film of serie, voor de
/// "Rolverdeling"-rij op het detailscherm (`CastRow`).
enum CreditsService {
    static func credits(for item: MediaItem) async -> TMDBCredits? {
        guard let tmdbID = item.tmdbID, let token = AppConfiguration.tmdbReadAccessToken else { return nil }

        let path = item.type == .movie ? "/3/movie/\(tmdbID)/credits" : "/3/tv/\(tmdbID)/credits"
        return await request(path: path, token: token)
    }

    private static func request<Response: Decodable>(path: String, token: String) async -> Response? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.themoviedb.org"
        components.path = path
        components.queryItems = [URLQueryItem(name: "language", value: CatalogLocalization.language)]

        guard let url = components.url else {
            print("[CreditsService] ongeldige URL voor \(path)")
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                print("[CreditsService] HTTP \(code) voor \(path)")
                return nil
            }
            do {
                return try JSONDecoder().decode(Response.self, from: data)
            } catch {
                print("[CreditsService] decode-fout voor \(path): \(error)")
                return nil
            }
        } catch {
            print("[CreditsService] netwerkfout voor \(path): \(error)")
            return nil
        }
    }
}

struct TMDBCredits: Decodable {
    let cast: [TMDBCastMember]
    let crew: [TMDBCrewMember]

    /// Regisseur (film: job "Director") of bedenker(s) (serie: job
    /// "Creator" -- TMDB geeft series-crew soms ook via `created_by` op de
    /// detailrespons, maar `credits.crew` bevat "Creator" ook, wat hier
    /// volstaat om ze samen met de cast te tonen).
    var directorsOrCreators: [TMDBCrewMember] {
        let jobs = Set(["Director", "Creator"])
        var seen = Set<Int>()
        return crew.filter { jobs.contains($0.job) && seen.insert($0.id).inserted }
    }
}

struct TMDBCastMember: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let character: String?
    let profilePath: String?
    let order: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, character
        case profilePath = "profile_path"
        case order
    }
}

struct TMDBCrewMember: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let job: String
    let department: String?
    let profilePath: String?

    enum CodingKeys: String, CodingKey {
        case id, name, job, department
        case profilePath = "profile_path"
    }
}
