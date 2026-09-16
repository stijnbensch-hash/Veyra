import Foundation

struct MediaItem: Identifiable, Hashable {
    let id: UUID
    let title: String
    let type: MediaType
    let imdbID: String?

    init(
        id: UUID = UUID(),
        title: String,
        type: MediaType,
        imdbID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.imdbID = imdbID
    }
}

enum MediaType: String, Hashable {
    case movie
    case series
    case liveTV
}
