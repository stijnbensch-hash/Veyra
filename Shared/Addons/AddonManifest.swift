import Foundation

struct AddonManifest:
    Codable,
    Identifiable,
    Equatable,
    Hashable
{
    var id: UUID
    var name: String
    var kind: AddonKind
    var baseURL: URL
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        kind: AddonKind,
        baseURL: URL,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.baseURL = baseURL
        self.isEnabled = isEnabled
    }
}

enum AddonKind:
    String,
    Codable,
    CaseIterable,
    Hashable
{
    case aioStreams
    case torrent
    case aioMetadata
}
