import Foundation

struct PlayableSource: Identifiable, Hashable {
    let id: UUID
    let name: String
    let description: String?
    let metadata: SourceMetadata?
    let url: URL
    let kind: SourceKind
    let requiresSoftwareVideo: Bool

    init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        metadata: SourceMetadata? = nil,
        url: URL,
        kind: SourceKind,
        requiresSoftwareVideo: Bool = false
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.metadata = metadata
        self.url = url
        self.kind = kind
        self.requiresSoftwareVideo = requiresSoftwareVideo
    }
}

enum SourceKind: String, Hashable {
    case usenet
    case debrid
    case liveTV
    case direct
}
