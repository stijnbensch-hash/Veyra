import Foundation

// MARK: - Media server kind

enum MediaServerKind:
    String,
    Codable,
    CaseIterable,
    Hashable
{
    case jellyfin
    case plex
    case emby

    var displayName: String {
        switch self {
        case .jellyfin:
            return "Jellyfin"

        case .plex:
            return "Plex"

        case .emby:
            return "Emby"
        }
    }

    var symbol: String {
        switch self {
        case .jellyfin:
            return "play.tv"

        case .plex:
            return "play.square.stack"

        case .emby:
            return "sparkles.tv"
        }
    }

    /// Server types that can actually be added today. The others are
    /// shown in the picker (as in Strand) but marked "Binnenkort".
    var isAvailable: Bool {
        switch self {
        case .jellyfin:
            return true

        case .plex, .emby:
            return false
        }
    }
}

// MARK: - Stored account

struct MediaServerAccount:
    Codable,
    Identifiable,
    Equatable,
    Hashable
{
    var id: UUID
    var name: String
    var kind: MediaServerKind
    var serverURL: URL
    var username: String
    var userID: String
    var accessToken: String

    /// True when this Jellyfin-compatible server is actually a Veyra Hub
    /// instance (detected via `VeyraHubVersion` in its `/System/Info/Public`
    /// response, at connect/reconnect time — see `JellyfinClient`). Lets
    /// source resolution skip the Jellyfin bridge's title search, which
    /// only works for addons with a searchable catalog, and call VeyraHub's
    /// native, IMDb-id-based API directly instead. See
    /// `VeyraHubNativeClient`.
    var isVeyraHub: Bool

    init(
        id: UUID = UUID(),
        name: String,
        kind: MediaServerKind,
        serverURL: URL,
        username: String,
        userID: String,
        accessToken: String,
        isVeyraHub: Bool = false
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.serverURL = serverURL
        self.username = username
        self.userID = userID
        self.accessToken = accessToken
        self.isVeyraHub = isVeyraHub
    }

    // Custom Decodable so accounts saved before `isVeyraHub` existed still
    // decode, defaulting to false (a plain Jellyfin server) instead of
    // failing to load.
    enum CodingKeys: String, CodingKey {
        case id, name, kind, serverURL, username, userID, accessToken, isVeyraHub
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        kind = try container.decode(MediaServerKind.self, forKey: .kind)
        serverURL = try container.decode(URL.self, forKey: .serverURL)
        username = try container.decode(String.self, forKey: .username)
        userID = try container.decode(String.self, forKey: .userID)
        accessToken = try container.decode(String.self, forKey: .accessToken)
        isVeyraHub = try container.decodeIfPresent(Bool.self, forKey: .isVeyraHub) ?? false
    }

    var host: String {
        serverURL.host
            ?? serverURL.absoluteString
    }
}

// MARK: - Notification

extension Notification.Name {
    static let veyraMediaServerConfigurationDidChange =
        Notification.Name(
            "VeyraMediaServerConfigurationDidChange"
        )
}

func notifyMediaServerChange() {
    NotificationCenter.default.post(
        name: .veyraMediaServerConfigurationDidChange,
        object: nil
    )
}
