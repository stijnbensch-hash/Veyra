import Foundation

/// Thin Jellyfin API client for one connected server account.
///
/// Used both to browse the user's own library (MediaServers) and,
/// via JellyfinSourceProvider, to resolve a direct stream for a
/// TMDB-matched movie or episode.
struct JellyfinService {
    let account: MediaServerAccount

    private let session: URLSession

    init(
        account: MediaServerAccount,
        session: URLSession = .shared
    ) {
        self.account = account
        self.session = session
    }

    // MARK: - Libraries

    func libraries() async throws -> [JellyfinLibrary] {
        let url = endpoint(
            "Users/\(account.userID)/Views"
        )

        let data = try await get(url)

        return try JellyfinLibrariesResponseDecoder.decode(data)
    }

    // MARK: - Items

    func items(
        parentID: String? = nil,
        includeItemTypes: [String],
        recursive: Bool = true,
        searchTerm: String? = nil,
        sortBy: String = "SortName",
        limit: Int? = nil
    ) async throws -> [JellyfinItem] {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(
                name: "IncludeItemTypes",
                value: includeItemTypes.joined(separator: ",")
            ),
            URLQueryItem(name: "Recursive", value: recursive ? "true" : "false"),
            URLQueryItem(name: "SortBy", value: sortBy),
            URLQueryItem(name: "SortOrder", value: "Ascending"),
            URLQueryItem(
                name: "Fields",
                value: "Overview,ProductionYear,Genres,CommunityRating"
            )
        ]

        if let parentID {
            queryItems.append(
                URLQueryItem(name: "ParentId", value: parentID)
            )
        }

        if let searchTerm, !searchTerm.isEmpty {
            queryItems.append(
                URLQueryItem(name: "SearchTerm", value: searchTerm)
            )
        }

        if let limit {
            queryItems.append(
                URLQueryItem(name: "Limit", value: String(limit))
            )
        }

        let url = endpoint(
            "Users/\(account.userID)/Items",
            queryItems: queryItems
        )

        let data = try await get(url)

        return try JellyfinItemsResponseDecoder.decode(data)
    }

    func search(
        term: String,
        includeItemTypes: [String]
    ) async throws -> [JellyfinItem] {
        let trimmed =
            term.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return []
        }

        return try await items(
            includeItemTypes: includeItemTypes,
            searchTerm: trimmed,
            limit: 20
        )
    }

    func episodes(
        seriesID: String
    ) async throws -> [JellyfinItem] {
        try await items(
            parentID: seriesID,
            includeItemTypes: ["Episode"],
            sortBy: "ParentIndexNumber,IndexNumber"
        )
    }

    func recentlyAdded(
        limit: Int = 20
    ) async throws -> [JellyfinItem] {
        let url = endpoint(
            "Users/\(account.userID)/Items/Latest",
            queryItems: [
                URLQueryItem(
                    name: "IncludeItemTypes",
                    value: "Movie,Episode"
                ),
                URLQueryItem(name: "Limit", value: String(limit)),
                URLQueryItem(
                    name: "Fields",
                    value: "Overview,ProductionYear,Genres,CommunityRating"
                )
            ]
        )

        let data = try await get(url)

        // "/Items/Latest" geeft rechtstreeks een array terug,
        // niet gewrapt in "Items".
        return try JSONDecoder().decode([JellyfinItem].self, from: data)
    }

    // MARK: - Media URLs

    func imageURL(
        for item: JellyfinItem,
        kind: JellyfinImageKind = .primary
    ) -> URL? {
        var components = URLComponents(
            url: account.serverURL,
            resolvingAgainstBaseURL: false
        )

        components?.path += "/Items/\(item.id)/Images/\(kind.rawValue)"

        components?.queryItems = [
            URLQueryItem(name: "api_key", value: account.accessToken),
            URLQueryItem(name: "quality", value: "90")
        ]

        return components?.url
    }

    func streamURL(for item: JellyfinItem) -> URL? {
        var components = URLComponents(
            url: account.serverURL,
            resolvingAgainstBaseURL: false
        )

        components?.path += "/Videos/\(item.id)/stream"

        components?.queryItems = [
            URLQueryItem(name: "static", value: "true"),
            URLQueryItem(name: "api_key", value: account.accessToken)
        ]

        return components?.url
    }

    // MARK: - Networking

    private func endpoint(
        _ path: String,
        queryItems: [URLQueryItem] = []
    ) -> URL {
        var components = URLComponents(
            url: account.serverURL,
            resolvingAgainstBaseURL: false
        )

        components?.path += "/\(path)"
        components?.queryItems =
            queryItems.isEmpty ? nil : queryItems

        return components?.url
            ?? account.serverURL.appendingPathComponent(path)
    }

    private func get(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)

        request.setValue(
            "MediaBrowser Token=\"\(account.accessToken)\"",
            forHTTPHeaderField: "X-Emby-Authorization"
        )

        request.setValue(
            account.accessToken,
            forHTTPHeaderField: "X-Emby-Token"
        )

        let (data, response) = try await session.data(for: request)

        guard
            let httpResponse = response as? HTTPURLResponse
        else {
            throw JellyfinServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw JellyfinServiceError.server(httpResponse.statusCode)
        }

        return data
    }
}

enum JellyfinImageKind: String {
    case primary = "Primary"
    case backdrop = "Backdrop/0"
}

enum JellyfinServiceError: LocalizedError {
    case invalidResponse
    case server(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "De mediaserver gaf een ongeldig antwoord."

        case .server(let code):
            return "De mediaserver reageerde met een fout (\(code))."
        }
    }
}

// MARK: - Decoding helpers

private enum JellyfinLibrariesResponseDecoder {
    private struct Response: Decodable {
        let items: [JellyfinLibrary]

        enum CodingKeys: String, CodingKey {
            case items = "Items"
        }
    }

    static func decode(_ data: Data) throws -> [JellyfinLibrary] {
        try JSONDecoder().decode(Response.self, from: data).items
    }
}

private enum JellyfinItemsResponseDecoder {
    private struct Response: Decodable {
        let items: [JellyfinItem]

        enum CodingKeys: String, CodingKey {
            case items = "Items"
        }
    }

    static func decode(_ data: Data) throws -> [JellyfinItem] {
        try JSONDecoder().decode(Response.self, from: data).items
    }
}
