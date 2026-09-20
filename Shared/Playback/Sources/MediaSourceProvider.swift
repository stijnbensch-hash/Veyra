import Foundation

protocol MediaSourceProvider {
    var name: String { get }

    func sources(for item: MediaItem) async throws -> [PlayableSource]
}
