import Foundation

struct MediaItem: Identifiable, Hashable {
    let id: UUID
    let title: String
    let type: MediaType

    init(
        id: UUID = UUID(),
        title: String,
        type: MediaType
    ) {
        self.id = id
        self.title = title
        self.type = type
    }
}

enum MediaType: String, Hashable {
    case movie
    case series
    case liveTV
}
