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

    init(
        id: UUID = UUID(),
        name: String,
        kind: MediaServerKind,
        serverURL: URL,
        username: String,
        userID: String,
        accessToken: String
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.serverURL = serverURL
        self.username = username
        self.userID = userID
        self.accessToken = accessToken
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
