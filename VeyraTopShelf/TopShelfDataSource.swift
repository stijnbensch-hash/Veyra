import Foundation
import Security

/// Zelfstandige, minimale kopie van de Trakt/Keychain-logica uit `Shared/`
/// voor gebruik in de VeyraTopShelf-extensie. De extensie deelt geen
/// `fileSystemSynchronizedGroups` met `Shared/` in het Xcode-project (zie
/// `project.pbxproj`), dus die code kan hier niet rechtstreeks hergebruikt
/// worden — dit dupliceert alleen wat nodig is om "Verder kijken" te tonen:
/// het gedeelde Keychain-item met de Trakt-sessie lezen (en zo nodig
/// verversen), en de "continue watching"-lijst + TMDB-achtergrond ophalen.
enum TopShelfKeychainAccessGroup {
    private static var cached: String?
    private static var didFail = false

    static var shared: String? {
        if let cached { return cached }
        guard !didFail else { return nil }

        let probeQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.veyra.shared.keychain-group-probe",
            kSecAttrAccount as String: "probe"
        ]

        SecItemDelete(probeQuery as CFDictionary)

        var addQuery = probeQuery
        addQuery[kSecValueData as String] = Data([0])
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        guard SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess else {
            didFail = true
            return nil
        }

        var readQuery = probeQuery
        readQuery[kSecReturnAttributes as String] = true

        var result: CFTypeRef?
        guard SecItemCopyMatching(readQuery as CFDictionary, &result) == errSecSuccess,
              let attributes = result as? [String: Any],
              let group = attributes[kSecAttrAccessGroup as String] as? String
        else {
            didFail = true
            return nil
        }

        cached = group
        return group
    }
}

struct TopShelfTraktToken: Codable {
    var accessToken: String
    var refreshToken: String
    var expiresIn: Double
    var createdAt: Double

    var expiresSoon: Bool {
        let expiresAt = createdAt + expiresIn
        return Date().timeIntervalSince1970 > expiresAt - 86400
    }
}

enum TopShelfKeychain {
    private static var accessGroup: String? { TopShelfKeychainAccessGroup.shared }

    private static func query(service: String, account: String) -> [String: Any] {
        var q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        if let accessGroup {
            q[kSecAttrAccessGroup as String] = accessGroup
        }
        return q
    }

    private static func readData(service: String, account: String) -> Data? {
        var q = query(service: service, account: account)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    private static func write(_ data: Data, service: String, account: String) {
        let base = query(service: service, account: account)
        let update: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        if SecItemUpdate(base as CFDictionary, update as CFDictionary) == errSecItemNotFound {
            SecItemAdd(base.merging(update) { _, new in new } as CFDictionary, nil)
        }
    }

    /// Leest de Trakt-sessie op uit hetzelfde keychain-item als de app
    /// (`TraktKeychain`: service "com.veyra.trakt", account "oauth").
    static func traktToken() -> TopShelfTraktToken? {
        guard let data = readData(service: "com.veyra.trakt", account: "oauth") else { return nil }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try? decoder.decode(TopShelfTraktToken.self, from: data)
    }

    static func saveTraktToken(_ token: TopShelfTraktToken) {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        guard let data = try? encoder.encode(token) else { return }
        write(data, service: "com.veyra.trakt", account: "oauth")
    }

    /// Leest een API-sleutel op uit hetzelfde gedeelde item als
    /// `VeyraAPIKeyStore` (service "com.veyra.shared.apikeys"), met
    /// dezelfde val-terug-op-het-oude-item-migratie als daar, zodat de
    /// extensie ook werkt vóórdat de app zelf al herstart is na de
    /// migratie.
    static func apiKey(account: String, legacyService: String?) -> String? {
        if let data = readData(service: "com.veyra.shared.apikeys", account: account),
           let value = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !value.isEmpty {
            return value
        }
        guard let legacyService,
              let data = readData(service: legacyService, account: account),
              let value = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty
        else { return nil }
        return value
    }
}

// MARK: - Trakt "continue watching"

private struct TopShelfIDs: Decodable { let tmdb: Int? }
private struct TopShelfMovieDTO: Decodable { let title: String; let ids: TopShelfIDs }
private struct TopShelfShowDTO: Decodable { let title: String; let ids: TopShelfIDs }
private struct TopShelfEpisodeDTO: Decodable { let season: Int; let number: Int }
private struct TopShelfPlaybackDTO: Decodable {
    let progress: Double
    let pausedAt: Date
    let type: String
    let movie: TopShelfMovieDTO?
    let episode: TopShelfEpisodeDTO?
    let show: TopShelfShowDTO?
}

struct TopShelfContinueItem {
    let title: String
    let subtitle: String?
    let tmdbID: Int?
    let isShow: Bool
}

enum TopShelfTraktAPI {
    /// Standaard-redirect-URI voor apps die geen eigen callback-URL
    /// registreren, zelfde vaste fallback als `AppConfiguration.traktRedirectURI`.
    private static let redirectURI = "urn:ietf:wg:oauth:2.0:oob"

    private static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .custom { decoder in
            let s = try decoder.singleValueContainer().decode(String.self)
            if let date = try? Date(s, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)) { return date }
            if let date = try? Date(s, strategy: Date.ISO8601FormatStyle()) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Ongeldige datum: \(s)"))
        }
        return d
    }

    /// Vernieuwt de sessie via Trakt's OAuth-refresh-endpoint en slaat het
    /// resultaat meteen weer op in het gedeelde keychain-item, zodat de
    /// app zelf de vernieuwde sessie ook meteen ziet.
    private static func refreshed(
        _ token: TopShelfTraktToken,
        clientID: String,
        clientSecret: String
    ) async -> TopShelfTraktToken? {
        guard let url = URL(string: "https://api.trakt.tv/oauth/token") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = [
            "refresh_token": token.refreshToken,
            "client_id": clientID,
            "client_secret": clientSecret,
            "redirect_uri": redirectURI,
            "grant_type": "refresh_token"
        ]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        request.httpBody = bodyData

        guard
            let (data, response) = try? await URLSession.shared.data(for: request),
            let http = response as? HTTPURLResponse,
            (200..<300).contains(http.statusCode)
        else { return nil }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let fresh = try? decoder.decode(TopShelfTraktToken.self, from: data) else { return nil }
        TopShelfKeychain.saveTraktToken(fresh)
        return fresh
    }

    /// Haalt maximaal `limit` "verder kijken"-items op, nieuwste eerst.
    static func continueWatching(limit: Int) async -> [TopShelfContinueItem] {
        guard
            let clientID = TopShelfKeychain.apiKey(account: "trakt.client-id", legacyService: Bundle.main.bundleIdentifier),
            var token = TopShelfKeychain.traktToken()
        else { return [] }

        if token.expiresSoon,
           let clientSecret = TopShelfKeychain.apiKey(account: "trakt.client-secret", legacyService: Bundle.main.bundleIdentifier),
           let fresh = await refreshed(token, clientID: clientID, clientSecret: clientSecret) {
            token = fresh
        }

        guard let url = URL(string: "https://api.trakt.tv/sync/playback?extended=full") else { return [] }
        var request = URLRequest(url: url)
        request.setValue("2", forHTTPHeaderField: "trakt-api-version")
        request.setValue(clientID, forHTTPHeaderField: "trakt-api-key")
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")

        guard
            let (data, response) = try? await URLSession.shared.data(for: request),
            let http = response as? HTTPURLResponse,
            (200..<300).contains(http.statusCode),
            let items = try? decoder().decode([TopShelfPlaybackDTO].self, from: data)
        else { return [] }

        return items
            .sorted { $0.pausedAt > $1.pausedAt }
            .prefix(limit)
            .compactMap { dto -> TopShelfContinueItem? in
                if let movie = dto.movie {
                    return TopShelfContinueItem(title: movie.title, subtitle: nil, tmdbID: movie.ids.tmdb, isShow: false)
                }
                if let show = dto.show, let episode = dto.episode {
                    return TopShelfContinueItem(
                        title: show.title,
                        subtitle: "S\(episode.season)E\(episode.number)",
                        tmdbID: show.ids.tmdb,
                        isShow: true
                    )
                }
                return nil
            }
    }
}

// MARK: - TMDB-achtergrond

private struct TopShelfTMDBImagesResponse: Decodable {
    struct Backdrop: Decodable { let filePath: String }
    let backdrops: [Backdrop]
}

enum TopShelfTMDBArtwork {
    static func backdropURL(isShow: Bool, tmdbID: Int) async -> URL? {
        guard let token = TopShelfKeychain.apiKey(
            account: "tmdb.read-access-token",
            legacyService: Bundle.main.bundleIdentifier
        ) else { return nil }

        let kind = isShow ? "tv" : "movie"
        guard let url = URL(string: "https://api.themoviedb.org/3/\(kind)/\(tmdbID)/images") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        guard
            let (data, response) = try? await URLSession.shared.data(for: request),
            let http = response as? HTTPURLResponse,
            (200..<300).contains(http.statusCode),
            let decoded = try? decoder.decode(TopShelfTMDBImagesResponse.self, from: data),
            let path = decoded.backdrops.first?.filePath
        else { return nil }

        return URL(string: "https://image.tmdb.org/t/p/w1280\(path)")
    }
}
