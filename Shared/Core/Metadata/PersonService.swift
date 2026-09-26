import Foundation

/// Biografie + filmografie van een acteur/regisseur/producer, voor
/// `PersonDetailView` (geopend door op iemand in `CastRow` te tikken).
enum PersonService {
    static func details(id: Int) async -> TMDBPersonDetails? {
        guard let token = AppConfiguration.tmdbReadAccessToken else { return nil }
        return await request(path: "/3/person/\(id)", token: token)
    }

    static func combinedCredits(id: Int) async -> [TMDBPersonCredit] {
        guard let token = AppConfiguration.tmdbReadAccessToken else { return [] }
        guard let response: TMDBPersonCombinedCredits = await request(
            path: "/3/person/\(id)/combined_credits", token: token
        ) else { return [] }

        // Eén titel kan meerdere keren voorkomen (bv. acteur én crewlid op
        // dezelfde film) -- op titel-id + type ontdubbelen, cast heeft
        // voorrang (rol i.p.v. crewfunctie) omdat dat is wat de gebruiker
        // meestal van deze persoon kent.
        var seen = Set<String>()
        var merged: [TMDBPersonCredit] = []
        for credit in response.cast + response.crew {
            let key = "\(credit.mediaType ?? "")-\(credit.id)"
            guard seen.insert(key).inserted else { continue }
            merged.append(credit)
        }

        return merged.sorted { ($0.sortDate ?? "") > ($1.sortDate ?? "") }
    }

    private static func request<Response: Decodable>(path: String, token: String) async -> Response? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.themoviedb.org"
        components.path = path
        components.queryItems = [URLQueryItem(name: "language", value: CatalogLocalization.language)]

        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode)
        else { return nil }

        return try? JSONDecoder().decode(Response.self, from: data)
    }
}

struct TMDBPersonDetails: Decodable {
    let id: Int
    let name: String
    let biography: String?
    let profilePath: String?
    let birthday: String?
    let deathday: String?
    let placeOfBirth: String?
    let knownForDepartment: String?

    enum CodingKeys: String, CodingKey {
        case id, name, biography
        case profilePath = "profile_path"
        case birthday
        case deathday
        case placeOfBirth = "place_of_birth"
        case knownForDepartment = "known_for_department"
    }

    /// Leeftijd (of leeftijd bij overlijden), afgeleid uit `birthday`/`deathday`
    /// ("yyyy-MM-dd", TMDB-formaat) -- `nil` als de geboortedatum onbekend is.
    var age: Int? {
        guard let birthday, let birthDate = Self.parse(birthday) else { return nil }
        let endDate = deathday.flatMap(Self.parse) ?? Date()
        return Calendar.current.dateComponents([.year], from: birthDate, to: endDate).year
    }

    private static func parse(_ raw: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: raw)
    }
}

private struct TMDBPersonCombinedCredits: Decodable {
    let cast: [TMDBPersonCredit]
    let crew: [TMDBPersonCredit]
}

/// Eén titel uit de filmografie van een persoon -- film of serie, als
/// acteur of als crewlid (regisseur/producer/...), door elkaar zoals TMDB
/// ze in `combined_credits` teruggeeft.
struct TMDBPersonCredit: Decodable, Hashable {
    let id: Int
    let mediaType: String?
    let title: String?
    let name: String?
    let character: String?
    let job: String?
    let posterPath: String?
    let releaseDate: String?
    let firstAirDate: String?
    let voteAverage: Double?
    let genreIDs: [Int]?

    enum CodingKeys: String, CodingKey {
        case id
        case mediaType = "media_type"
        case title
        case name
        case character
        case job
        case posterPath = "poster_path"
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case voteAverage = "vote_average"
        case genreIDs = "genre_ids"
    }

    var isMovie: Bool { mediaType == "movie" || (mediaType == nil && title != nil) }
    var displayTitle: String { (isMovie ? title : name) ?? title ?? name ?? "Onbekende titel" }
    var displayDate: String? { isMovie ? releaseDate : firstAirDate }
    var displayYear: String? {
        guard let displayDate, displayDate.count >= 4 else { return nil }
        return String(displayDate.prefix(4))
    }
    /// Rol als acteur, anders crewfunctie (regisseur, producer, ...).
    var roleLabel: String? { character?.isEmpty == false ? character : job }
    fileprivate var sortDate: String? { displayDate }

    func mediaItem() -> MediaItem {
        MediaItem(
            title: displayTitle,
            type: isMovie ? .movie : .series,
            tmdbID: id,
            releaseDate: displayDate,
            posterURL: posterPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w500\($0)") },
            genre: isMovie ? TMDBGenreNames.firstMovieName(for: genreIDs ?? []) : TMDBGenreNames.firstTVName(for: genreIDs ?? []),
            rating: voteAverage
        )
    }
}
