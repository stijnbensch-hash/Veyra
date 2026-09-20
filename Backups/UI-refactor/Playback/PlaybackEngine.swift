import Foundation

protocol PlaybackEngine {
    func play(_ source: PlayableSource) async throws
    func stop()
}
