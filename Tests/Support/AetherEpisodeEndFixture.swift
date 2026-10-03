import Combine
public enum PlaybackState: Equatable { case idle, loading, playing, paused, seeking, ended, error }
@MainActor public final class AetherEngine: ObservableObject {
    @Published public var state: PlaybackState = .idle
    public init() {}
}
