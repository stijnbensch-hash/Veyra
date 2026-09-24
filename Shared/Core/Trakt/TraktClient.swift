import Foundation

struct TraktCredentials {
    let clientID: String
    let clientSecret: String
    let redirectURI: String
    static var configured: TraktCredentials? {
        guard let id = AppConfiguration.traktClientID,
              let secret = AppConfiguration.traktClientSecret else { return nil }
        return TraktCredentials(clientID: id, clientSecret: secret,
                                redirectURI: AppConfiguration.traktRedirectURI)
    }
}

enum TraktError: LocalizedError {
    case configuration, signedOut, storage, invalidResponse, missingMedia, expiredCode
    case http(Int, Double?, String?)
    var errorDescription: String? {
        switch self {
        case .configuration: return "Trakt is nog niet ingesteld voor deze versie van Veyra."
        case .signedOut: return "Koppel je Trakt-account opnieuw."
        case .storage: return "De Trakt-koppeling kon niet veilig worden opgeslagen of verwijderd."
        case .invalidResponse: return "Trakt gaf een onverwacht antwoord. Probeer opnieuw."
        case .missingMedia: return "Deze titel is niet gevonden in Trakt."
        case .expiredCode: return "De koppelcode is verlopen. Vraag een nieuwe code aan."
        case .http(let code, _, _):
            switch code {
            case 401: return "Je Trakt-koppeling is verlopen. Koppel je account opnieuw."
            case 403: return "Trakt geeft geen toegang tot deze functie."
            case 404: return "Dit item of deze koppelcode bestaat niet meer in Trakt."
            case 409: return "Deze actie is al verwerkt. Vernieuw de gegevens."
            case 410: return "De koppelcode is verlopen. Vraag een nieuwe code aan."
            case 418: return "Je hebt de Trakt-koppeling geweigerd."
            case 420: return "De limiet van je Trakt-account voor deze functie is bereikt."
            case 429: return "Trakt vraagt even te wachten. Probeer het later opnieuw."
            case 500...599: return "Trakt is tijdelijk niet bereikbaar. Probeer het later opnieuw."
            default: return "Trakt kon de actie niet uitvoeren (\(code))."
            }
        }
    }
}

@MainActor
final class TraktClient {
    private let session: URLSession
    // Vaste credentials voor tests/previews. In de echte app blijft dit `nil`
    // en wordt `credentials` bij elke aanroep opnieuw uit AppConfiguration
    // gelezen — anders blijft een Trakt-client die is aangemaakt vóórdat de
    // gebruiker zijn Client ID/Secret invulde (bijv. in Account op iOS)
    // permanent "niet ingesteld" tot een herstart van de app.
    private let explicitCredentials: TraktCredentials?
    private var credentials: TraktCredentials? { explicitCredentials ?? TraktCredentials.configured }
    private let keychain: any TraktTokenStorage
    private var token: TraktToken?
    private var refreshTask: Task<TraktToken, Error>?
    private var generation = UUID()
    private var retryAfter: Date?
    let decoder: JSONDecoder
    let encoder: JSONEncoder
    private(set) var restorationError: Error?
    var isAuthenticated: Bool { token != nil }
    var isConfigured: Bool { credentials != nil }

    convenience init() { self.init(credentials: nil) }

    init(credentials: TraktCredentials?, session: URLSession = URLSession(configuration: .ephemeral),
         tokenStorage: (any TraktTokenStorage)? = nil, restoreToken: Bool = true) {
        self.keychain = tokenStorage ?? TraktKeychain()
        self.explicitCredentials = credentials
        self.session = session
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        if restoreToken {
            do {
                if let data = try keychain.read() { token = try decoder.decode(TraktToken.self, from: data) }
            } catch { restorationError = error }
        }
    }

    func deviceCode() async throws -> TraktDeviceCode {
        guard let credentials else { throw TraktError.configuration }
        return try await oauth("device/code", body: ["client_id": credentials.clientID])
    }

    func authorize(_ code: TraktDeviceCode, receivedAt: Date) async throws {
        guard let credentials else { throw TraktError.configuration }
        let sessionID = generation
        let deadline = receivedAt.addingTimeInterval(code.expiresIn)
        var interval = max(1, code.interval)
        while Date() < deadline {
            try await Task.sleep(for: .seconds(min(interval, max(0, deadline.timeIntervalSinceNow))))
            try Task.checkCancellation()
            guard Date() < deadline else { break }
            do {
                let value: TraktToken = try await oauth("device/token", body: [
                    "code": code.deviceCode, "client_id": credentials.clientID,
                    "client_secret": credentials.clientSecret
                ])
                try Task.checkCancellation()
                guard generation == sessionID else { throw CancellationError() }
                try save(value)
                return
            } catch TraktError.http(let status, let retry, let oauthError) {
                if status == 400 && (oauthError == nil || oauthError == "authorization_pending") { continue }
                if status == 429 { interval = max(interval + 5, retry ?? 0); continue }
                throw TraktError.http(status, retry, oauthError)
            }
        }
        throw TraktError.expiredCode
    }

    private func save(_ value: TraktToken) throws {
        try keychain.save(encoder.encode(value))
        token = value
    }

    private func accessToken(forceRefresh: Bool = false, rejectedToken: String? = nil) async throws -> String {
        guard let credentials else { throw TraktError.configuration }
        guard let current = token else { throw TraktError.signedOut }
        if let rejectedToken, current.accessToken != rejectedToken { return current.accessToken }
        if let refreshTask { return try await refreshTask.value.accessToken }
        if !current.expiresSoon && !forceRefresh { return current.accessToken }
        let sessionID = generation
        let task = Task { @MainActor in
            let value: TraktToken = try await self.oauth("token", body: [
                "refresh_token": current.refreshToken, "client_id": credentials.clientID,
                "client_secret": credentials.clientSecret, "redirect_uri": credentials.redirectURI,
                "grant_type": "refresh_token"
            ])
            try Task.checkCancellation()
            guard self.generation == sessionID else { throw CancellationError() }
            try self.save(value)
            return value
        }
        refreshTask = task
        defer { if generation == sessionID { refreshTask = nil } }
        do { return try await task.value.accessToken }
        catch TraktError.http(let status, let retry, let reason) {
            if generation == sessionID && (status == 401 || (status == 400 && reason == "invalid_grant")) {
                token = nil
                try keychain.delete()
            }
            throw TraktError.http(status, retry, reason)
        }
    }

    func disconnect() async throws {
        let previous = token
        // Invalidate in-flight work before awaiting network revocation.
        try keychain.delete()
        generation = UUID()
        refreshTask?.cancel()
        refreshTask = nil
        token = nil
        if let previous, let credentials {
            _ = try await send(path: "oauth/revoke", host: "auth.trakt.tv", method: "POST", body: [
                "token": previous.accessToken, "client_id": credentials.clientID,
                "client_secret": credentials.clientSecret
            ])
        }
    }

    /// Voor de bento-home: een geldig access-token (ververst zo nodig via dezelfde sessie) en het client-ID.
    func validAccessToken() async throws -> String { try await accessToken() }
    var clientID: String? { credentials?.clientID }

    private func oauth<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        let response = try await send(path: "oauth/\(path)", host: "auth.trakt.tv", method: "POST", body: body)
        return try decoder.decode(T.self, from: response.0)
    }

    func request<T: Decodable>(_ path: String, method: String = "GET",
                               body: [String: Any]? = nil) async throws -> T {
        let (data, _) = try await authenticated(path, method: method, body: body)
        return try decoder.decode(T.self, from: data)
    }

    func delete(_ path: String) async throws {
        _ = try await authenticated(path, method: "DELETE", body: nil)
    }

    /// Voor Trakt-endpoints die geen ingelogde gebruiker vereisen (bijv.
    /// `/movies/:id/ratings`) — enkel de Client ID/Secret zijn nodig, geen
    /// OAuth-token. Zo tonen we de Trakt-community-rating ook wanneer de
    /// gebruiker zijn account niet gekoppeld heeft.
    func publicRequest<T: Decodable>(_ path: String) async throws -> T {
        let (data, _) = try await send(path: path, method: "GET", body: nil)
        return try decoder.decode(T.self, from: data)
    }

    func allPages<T: Decodable>(_ path: String) async throws -> [T] {
        var result: [T] = []
        var page = 1
        while true {
            try Task.checkCancellation()
            let separator = path.contains("?") ? "&" : "?"
            let (data, response) = try await authenticated("\(path)\(separator)page=\(page)&limit=100", method: "GET", body: nil)
            result += try decoder.decode([T].self, from: data)
            let pages = Int(response.value(forHTTPHeaderField: "X-Pagination-Page-Count") ?? "1") ?? 1
            if page >= pages { return result }
            page += 1
        }
    }

    private func authenticated(_ path: String, method: String, body: [String: Any]?) async throws -> (Data, HTTPURLResponse) {
        let sessionID = generation
        let access = try await accessToken()
        do {
            let result = try await send(path: path, method: method, body: body, access: access)
            guard generation == sessionID else { throw CancellationError() }
            return result
        } catch TraktError.http(401, _, _) {
            guard generation == sessionID else { throw CancellationError() }
            let renewed = try await accessToken(forceRefresh: true, rejectedToken: access)
            let result = try await send(path: path, method: method, body: body, access: renewed)
            guard generation == sessionID else { throw CancellationError() }
            return result
        }
    }

    private func send(path: String, host: String = "api.trakt.tv", method: String,
                      body: [String: Any]?, access: String? = nil) async throws -> (Data, HTTPURLResponse) {
        guard let credentials else { throw TraktError.configuration }
        if let retryAfter, retryAfter > Date() { throw TraktError.http(429, retryAfter.timeIntervalSinceNow, nil) }
        guard let url = URL(string: "https://\(host)/\(path)") else { throw TraktError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("2", forHTTPHeaderField: "trakt-api-version")
        request.setValue(credentials.clientID, forHTTPHeaderField: "trakt-api-key")
        if let access { request.setValue("Bearer \(access)", forHTTPHeaderField: "Authorization") }
        if let body { request.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw TraktError.invalidResponse }
        guard (200...299).contains(response.statusCode) else {
            let retry = response.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init)
            if response.statusCode == 429 { retryAfter = Date().addingTimeInterval(retry ?? 10) }
            let errorBody = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            throw TraktError.http(response.statusCode, retry, errorBody?["error"] as? String)
        }
        return (data, response)
    }
}
