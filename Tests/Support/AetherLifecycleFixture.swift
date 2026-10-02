// Minimal dependency fixture for testing the real PlaybackViewModel's ownership logic.
// It intentionally allows load to finish after cancellation, reproducing stale completions.
import Foundation
public enum FixtureBackend { case native, software }
public struct FixtureOptions { public var preferredDecodePath: FixtureBackend = .native }
@MainActor public final class AetherEngine {
    public var hasFirstFrameReadyForDisplay = true
    public var playbackBackend = FixtureBackend.native
    public init() {}
    public func play() {}
    public func reloadAtCurrentPosition(_ update: (inout FixtureOptions) -> Void) async throws {}
}
