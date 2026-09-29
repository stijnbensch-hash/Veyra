import Foundation

/// Eén item van TMDB's `/movie/{id}/reviews` of `/tv/{id}/reviews`-endpoint --
/// door kijkers geschreven recensies (Engelstalig, TMDB vertaalt deze niet).
struct TMDBReview: Decodable, Identifiable, Hashable {
    let id: String
    let author: String
    let content: String
    let url: String
    let authorDetails: TMDBReviewAuthor?

    enum CodingKeys: String, CodingKey {
        case id, author, content, url
        case authorDetails = "author_details"
    }
}

struct TMDBReviewAuthor: Decodable, Hashable {
    let name: String?
    let username: String?
    let avatarPath: String?
    let rating: Double?

    enum CodingKeys: String, CodingKey {
        case name, username, rating
        case avatarPath = "avatar_path"
    }
}

extension TMDBReview {
    /// TMDB laat het weergavenaam-veld vaak leeg; de gebruikersnaam blijft
    /// dan de enige bruikbare naam.
    var displayName: String {
        let name = authorDetails?.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let name, !name.isEmpty { return name }
        return author
    }

    var rating: Double? { authorDetails?.rating }

    /// TMDB-avatars zijn soms een extern (Gravatar) pad dat al met "/https://"
    /// begint i.p.v. een TMDB-beeldpad.
    var avatarURL: URL? {
        guard let path = authorDetails?.avatarPath, !path.isEmpty else { return nil }
        if path.hasPrefix("/http") { return URL(string: String(path.dropFirst())) }
        return URL(string: "https://image.tmdb.org/t/p/w185\(path)")
    }
}

struct TMDBReviewsResponse: Decodable {
    let results: [TMDBReview]
}
