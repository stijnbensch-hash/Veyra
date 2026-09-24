import Foundation

/// `Sendable` zodat providers parallel (via een TaskGroup) bevraagd kunnen
/// worden in `SourceResolver` — anders moet elke addon/mediaserver op zijn
/// beurt wachten, wat het zoeken naar bronnen merkbaar vertraagt.
protocol MediaSourceProvider: Sendable {
    var name: String { get }

    func sources(for item: MediaItem) async throws -> [PlayableSource]
}
