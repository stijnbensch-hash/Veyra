import Foundation

/// Minimal Jellyfin client, used only to verify a server and sign in
/// when the user adds a media server from Settings.
struct JellyfinClient {
    struct AuthResult {
        let userID: String
        let accessToken: String
        let serverName: String?
    }

    private let deviceID: String
    private let deviceName: String

    init(
        deviceID: String =
            JellyfinClient.persistentDeviceID(),
        deviceName: String =
            JellyfinClient.currentDeviceName()
    ) {
        self.deviceID = deviceID
        self.deviceName = deviceName
    }

    // MARK: - Authenticate

    func authenticate(
        serverURL: URL,
        username: String,
        password: String
    ) async throws -> AuthResult {
        let endpoint =
            serverURL.appendingPathComponent(
                "Users/AuthenticateByName"
            )

        var request =
            URLRequest(url: endpoint)

        request.httpMethod = "POST"

        request.setValue(
            "application/json",
            forHTTPHeaderField:
                "Content-Type"
        )

        request.setValue(
            authorizationHeader,
            forHTTPHeaderField:
                "X-Emby-Authorization"
        )

        let body: [String: String] = [
            "Username": username,
            "Pw": password
        ]

        request.httpBody =
            try JSONEncoder()
                .encode(body)

        let (data, response):
            (Data, URLResponse)

        do {
            (data, response) =
                try await URLSession
                    .shared
                    .data(for: request)
        } catch {
            throw JellyfinClientError
                .network(error)
        }

        guard
            let httpResponse =
                response as? HTTPURLResponse
        else {
            throw JellyfinClientError
                .invalidResponse
        }

        guard
            httpResponse.statusCode == 200
        else {
            if httpResponse.statusCode == 401 {
                throw JellyfinClientError
                    .invalidCredentials
            }

            throw JellyfinClientError
                .server(
                    httpResponse.statusCode
                )
        }

        guard
            let payload =
                try? JSONDecoder()
                    .decode(
                        AuthenticateResponse.self,
                        from: data
                    )
        else {
            throw JellyfinClientError
                .invalidResponse
        }

        return AuthResult(
            userID: payload.user.id,
            accessToken:
                payload.accessToken,
            serverName:
                payload.serverName
        )
    }

    // MARK: - Header

    private var authorizationHeader: String {
        "MediaBrowser Client=\"Veyra\", "
            + "Device=\"\(deviceName)\", "
            + "DeviceId=\"\(deviceID)\", "
            + "Version=\"1.0.0\""
    }

    static func persistentDeviceID() -> String {
        let key =
            "veyra.jellyfin.device-id"

        if
            let existing =
                UserDefaults.standard
                    .string(forKey: key)
        {
            return existing
        }

        let generated =
            UUID().uuidString

        UserDefaults.standard.set(
            generated,
            forKey: key
        )

        return generated
    }

    static func currentDeviceName() -> String {
        #if os(tvOS)
        return "Apple TV"
        #elseif os(iOS)
        return "iPhone of iPad"
        #else
        return "Veyra"
        #endif
    }
}

// MARK: - Response models

private struct AuthenticateResponse: Decodable {
    let user: JellyfinUser
    let accessToken: String
    let serverName: String?

    enum CodingKeys: String, CodingKey {
        case user = "User"
        case accessToken = "AccessToken"
        case serverName = "ServerId"
    }
}

private struct JellyfinUser: Decodable {
    let id: String
    let name: String?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
    }
}

// MARK: - Errors

enum JellyfinClientError:
    LocalizedError
{
    case invalidURL
    case invalidCredentials
    case invalidResponse
    case server(Int)
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Vul een geldige server-URL in."

        case .invalidCredentials:
            return "Gebruikersnaam of wachtwoord onjuist."

        case .invalidResponse:
            return "Onverwacht antwoord van de server."

        case .server(let code):
            return "De server reageerde met een fout (\(code))."

        case .network(let error):
            return "Kan geen verbinding maken: \(error.localizedDescription)"
        }
    }
}

// MARK: - URL helper

func validatedServerURL(
    _ value: String
) -> URL? {
    var trimmed =
        value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

    guard !trimmed.isEmpty else {
        return nil
    }

    if !trimmed.contains("://") {
        trimmed = "http://" + trimmed
    }

    guard
        var components =
            URLComponents(string: trimmed),
        let scheme =
            components.scheme?
                .lowercased(),
        scheme == "http" || scheme == "https",
        components.host != nil
    else {
        return nil
    }

    components.fragment = nil

    if components.path.hasSuffix("/") {
        components.path.removeLast()
    }

    return components.url
}
