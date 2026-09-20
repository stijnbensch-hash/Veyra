import Foundation

struct PlayableSource: Identifiable, Hashable {
    let id: UUID

    let name: String
    let description: String?

    let metadata: SourceMetadata?

    let url: URL
    let kind: SourceKind

    // Exacte zichtbare naam van de addon/provider.
    //
    // Voorbeeld:
    // "AIOStreams"
    // "PenguPlay"
    // "IPTV"
    let providerName: String?

    let requiresSoftwareVideo: Bool

    init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        metadata: SourceMetadata? = nil,
        url: URL,
        kind: SourceKind,
        providerName: String? = nil,
        requiresSoftwareVideo: Bool = false
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.metadata = metadata
        self.url = url
        self.kind = kind
        self.providerName = providerName
        self.requiresSoftwareVideo =
            requiresSoftwareVideo
    }
}

enum SourceKind: String, Hashable {
    case usenet
    case debrid
    case liveTV
    case direct
    case iptvVOD
}
