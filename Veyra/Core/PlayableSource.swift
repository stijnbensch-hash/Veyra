import Foundation

struct PlayableSource: Identifiable, Hashable {
    let id: UUID
    let name: String
    let description: String?
    let url: URL
    let kind: SourceKind

    init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        url: URL,
        kind: SourceKind
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.url = url
        self.kind = kind
    }
}

enum SourceKind: String, Hashable {
    case usenet
    case debrid
    case liveTV
    case direct
}
