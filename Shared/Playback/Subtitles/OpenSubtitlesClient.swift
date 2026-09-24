import Foundation

actor OpenSubtitlesClient {
    private let session:
        URLSession

    private let baseURL =
        URL(
            string:
                "https://api.opensubtitles.com/api/v1/"
        )!

    init(
        session:
            URLSession = .shared
    ) {
        self.session =
            session
    }

    func search(
        imdbID: String,
        type: MediaType,
        seasonNumber: Int?,
        episodeNumber: Int?,
        languages: [String]
    ) async throws
        -> [OpenSubtitlesResult]
    {
        let configuredAPIKey =
            await MainActor.run {
                AppConfiguration
                    .openSubtitlesAPIKey
            }

        guard
            let apiKey =
                configuredAPIKey,
            !apiKey.isEmpty
        else {
            throw OpenSubtitlesError
                .missingAPIKey
        }

        guard
            let numericIMDbID =
                Self.numericIMDbID(
                    imdbID
                )
        else {
            throw OpenSubtitlesError
                .invalidIMDbID
        }

        var components =
            URLComponents(
                url:
                    baseURL
                        .appendingPathComponent(
                            "subtitles"
                        ),
                resolvingAgainstBaseURL:
                    false
            )

        var queryItems: [
            URLQueryItem
        ] = [
            URLQueryItem(
                name: "languages",
                value:
                    languages
                        .joined(
                            separator: ","
                        )
            )
        ]

        switch type {
        case .movie:
            queryItems.append(
                URLQueryItem(
                    name: "imdb_id",
                    value:
                        numericIMDbID
                )
            )

            queryItems.append(
                URLQueryItem(
                    name: "type",
                    value: "movie"
                )
            )

        case .series:
            guard
                let seasonNumber,
                let episodeNumber
            else {
                return []
            }

            queryItems.append(
                URLQueryItem(
                    name:
                        "parent_imdb_id",
                    value:
                        numericIMDbID
                )
            )

            queryItems.append(
                URLQueryItem(
                    name:
                        "season_number",
                    value:
                        String(
                            seasonNumber
                        )
                )
            )

            queryItems.append(
                URLQueryItem(
                    name:
                        "episode_number",
                    value:
                        String(
                            episodeNumber
                        )
                )
            )

            queryItems.append(
                URLQueryItem(
                    name: "type",
                    value: "episode"
                )
            )

        case .liveTV, .iptvSeries:
            return []
        }

        components?
            .queryItems =
            queryItems

        guard
            let url =
                components?.url
        else {
            throw OpenSubtitlesError
                .invalidURL
        }

        var request =
            URLRequest(
                url: url
            )

        request.timeoutInterval =
            20

        request.setValue(
            apiKey,
            forHTTPHeaderField:
                "Api-Key"
        )

        request.setValue(
            Self.userAgent,
            forHTTPHeaderField:
                "User-Agent"
        )

        request.setValue(
            "application/json",
            forHTTPHeaderField:
                "Accept"
        )

        let (
            data,
            response
        ) =
            try await session.data(
                for: request
            )

        try Task
            .checkCancellation()

        try Self
            .validate(
                response
            )

        let decoded =
            try JSONDecoder()
                .decode(
                    OpenSubtitlesSearchResponse
                        .self,
                    from: data
                )

        return Self
            .mapResults(
                decoded.data
            )
    }

    func download(
        fileID: Int
    ) async throws
        -> URL
    {
        let configuredAPIKey =
            await MainActor.run {
                AppConfiguration
                    .openSubtitlesAPIKey
            }

        guard
            let apiKey =
                configuredAPIKey,
            !apiKey.isEmpty
        else {
            throw OpenSubtitlesError
                .missingAPIKey
        }

        let url =
            baseURL
                .appendingPathComponent(
                    "download"
                )

        var request =
            URLRequest(
                url: url
            )

        request.httpMethod =
            "POST"

        request.timeoutInterval =
            20

        request.setValue(
            apiKey,
            forHTTPHeaderField:
                "Api-Key"
        )

        request.setValue(
            Self.userAgent,
            forHTTPHeaderField:
                "User-Agent"
        )

        request.setValue(
            "application/json",
            forHTTPHeaderField:
                "Accept"
        )

        request.setValue(
            "application/json",
            forHTTPHeaderField:
                "Content-Type"
        )

        request.httpBody =
            try JSONEncoder()
                .encode(
                    OpenSubtitlesDownloadRequest(
                        fileID:
                            fileID
                    )
                )

        let (
            data,
            response
        ) =
            try await session.data(
                for: request
            )

        try Task
            .checkCancellation()

        try Self
            .validate(
                response
            )

        let decoded =
            try JSONDecoder()
                .decode(
                    OpenSubtitlesDownloadResponse
                        .self,
                    from: data
                )

        return decoded.link
    }

    private static var userAgent:
        String
    {
        let version =
            Bundle.main
                .object(
                    forInfoDictionaryKey:
                        "CFBundleShortVersionString"
                )
                as? String
            ?? "1.0"

        return "Veyra v\(version)"
    }

    private static func numericIMDbID(
        _ value: String
    ) -> String? {
        let cleaned =
            value
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .lowercased()

        let numeric =
            cleaned.hasPrefix("tt")
            ? String(
                cleaned.dropFirst(2)
            )
            : cleaned

        guard
            !numeric.isEmpty,
            numeric.allSatisfy(
                \.isNumber
            )
        else {
            return nil
        }

        return numeric
    }

    private static func validate(
        _ response: URLResponse
    ) throws {
        guard
            let http =
                response
                    as? HTTPURLResponse
        else {
            throw OpenSubtitlesError
                .invalidResponse
        }

        guard
            (200...299)
                .contains(
                    http.statusCode
                )
        else {
            throw OpenSubtitlesError
                .http(
                    http.statusCode
                )
        }
    }

    private static func mapResults(
        _ values:
            [OpenSubtitlesSubtitle]
    ) -> [OpenSubtitlesResult] {
        var result:
            [OpenSubtitlesResult] = []

        var seenFileIDs =
            Set<Int>()

        for subtitle
            in values
        {
            guard
                let file =
                    subtitle
                        .attributes
                        .files
                        .first,
                seenFileIDs
                    .insert(
                        file.fileID
                    )
                    .inserted
            else {
                continue
            }

            let language =
                normalizedLanguage(
                    subtitle
                        .attributes
                        .language
                )

            result.append(
                OpenSubtitlesResult(
                    id:
                        "\(subtitle.id)-\(file.fileID)",
                    fileID:
                        file.fileID,
                    language:
                        language,
                    displayLanguage:
                        displayLanguage(
                            language
                        ),
                    name:
                        cleanName(
                            subtitle
                                .attributes
                                .release
                        )
                        ?? cleanName(
                            file.fileName
                        )
                        ?? "OpenSubtitles",
                    hearingImpaired:
                        subtitle
                            .attributes
                            .hearingImpaired
                        ?? false,
                    forced:
                        subtitle
                            .attributes
                            .forced
                        ?? false
                )
            )
        }

        return result
    }

    private static func normalizedLanguage(
        _ value: String?
    ) -> String {
        let code =
            value?
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .lowercased()
            ?? "und"

        switch code {
        case "dut", "nld":
            return "nl"

        case "eng":
            return "en"

        default:
            return code
        }
    }

    private static func displayLanguage(
        _ language: String
    ) -> String {
        if language == "nl" {
            return "Nederlands"
        }

        if language == "en" {
            return "English"
        }

        return Locale(
            identifier: "nl_BE"
        )
        .localizedString(
            forLanguageCode:
                language
        )
        ?? language.uppercased()
    }

    private static func cleanName(
        _ value: String?
    ) -> String? {
        guard
            let value
        else {
            return nil
        }

        let cleaned =
            value
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        return cleaned.isEmpty
            ? nil
            : cleaned
    }
}

enum OpenSubtitlesError:
    LocalizedError
{
    case missingAPIKey
    case invalidIMDbID
    case invalidURL
    case invalidResponse
    case http(Int)

    var errorDescription:
        String?
    {
        switch self {
        case .missingAPIKey:
            return "Er is geen OpenSubtitles API-sleutel ingesteld."

        case .invalidIMDbID:
            return "De IMDb-ID is ongeldig."

        case .invalidURL:
            return "De OpenSubtitles-aanvraag kon niet worden opgebouwd."

        case .invalidResponse:
            return "OpenSubtitles gaf een ongeldig antwoord."

        case .http(let code):
            return "OpenSubtitles gaf HTTP \(code)."
        }
    }
}
