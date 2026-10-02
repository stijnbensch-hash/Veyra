import Foundation
import SwiftUI
import AetherEngine

nonisolated struct MediaItem: Sendable {}
nonisolated struct PlayableSource: Sendable {
    enum Kind: Sendable { case movie, liveTV, iptvVOD }
    let kind: Kind
    var progressSync: FixtureSync? { nil }
    var recorderCleanup: String? { nil }
}
nonisolated struct FixtureSync: Sendable { let account: String; let mediaType: String; let mediaID: String }
nonisolated struct FixtureProgress { let found = false; let positionSeconds: Double? = nil; let durationSeconds: Double? = nil }
@MainActor struct VeyraHubNativeClient {
    init(account: String) {}
    func progress(type: String, id: String) async throws -> FixtureProgress { FixtureProgress() }
    func setProgress(type: String, id: String, positionSeconds: Double, durationSeconds: Double) async throws {}
}
@MainActor final class TraktStore {
    static let shared = TraktStore()
    func wasProgressReset(for item: MediaItem) -> Bool { false }
    func clearProgressReset(for item: MediaItem) {}
}
@MainActor final class FixtureTracker {
    init(item: MediaItem, engine: AetherEngine) {}
    init(sync: FixtureSync, engine: AetherEngine) {}
    init(cleanup: String, engine: AetherEngine) {}
    func finish() {}
}
typealias TraktPlaybackTracker = FixtureTracker
typealias VeyraHubPlaybackTracker = FixtureTracker
typealias VeyraLocalWatchTracker = FixtureTracker
typealias VeyraHubRecorderCleanupTracker = FixtureTracker
@MainActor enum LiveChannelFallbackResolver {
    static func resolve(after source: PlayableSource) async -> PlayableSource? { nil }
}
@MainActor final class SubtitleService {
    static let shared = SubtitleService()
    var delay = false
    var waiting: CheckedContinuation<Void, Never>?
    func reset() {}
    func loadExternalSubtitles(for item: MediaItem, into engine: AetherEngine) async {
        if delay { await withCheckedContinuation { waiting = $0 } }
    }
}
@MainActor final class AetherPlaybackEngine {
    static var instances: [AetherPlaybackEngine] = []
    let engine = AetherEngine()
    var stopped = false
    var isActiveSession: Bool { !stopped }
    var waiting: CheckedContinuation<Void, Error>?
    init() throws { Self.instances.append(self) }
    func play(_ source: PlayableSource, resumeProgress: Double?) async throws {
        try await withCheckedThrowingContinuation { waiting = $0 }
    }
    func stop() { stopped = true }
    func complete() { waiting?.resume(); waiting = nil }
}

@main
struct PlaybackLifecycleChecks {
    @MainActor static func waitUntil(_ check: () -> Bool) async throws {
        for _ in 0..<100 {
            if check() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        preconditionFailure("Expected lifecycle transition did not occur")
    }
    @MainActor static func main() async throws {
        let model = PlaybackViewModel(source: .init(kind: .movie), item: nil, resumeProgress: nil)
        let oldStart = Task { await model.startPlayback() }
        try await waitUntil { AetherPlaybackEngine.instances.count == 1 && AetherPlaybackEngine.instances[0].waiting != nil }
        let old = AetherPlaybackEngine.instances[0]
        await model.startPlayback()
        precondition(AetherPlaybackEngine.instances.count == 1, "Repeated .task must not allocate a second engine")
        model.stopForDisappear()
        let newStart = Task { await model.startPlayback() }
        try await waitUntil { AetherPlaybackEngine.instances.count == 2 && AetherPlaybackEngine.instances[1].waiting != nil }
        let new = AetherPlaybackEngine.instances[1]
        old.complete()
        await oldStart.value
        precondition(model.playbackEngine === new && !new.stopped, "A stale completion must not stop the new session")
        new.complete()
        await newStart.value
        model.stopForDisappear()
        precondition(new.stopped && model.playbackEngine == nil)

        let cancelledModel = PlaybackViewModel(source: .init(kind: .movie), item: nil, resumeProgress: nil)
        let cancelledStart = Task { await cancelledModel.startPlayback() }
        try await waitUntil { AetherPlaybackEngine.instances.count == 3 && AetherPlaybackEngine.instances[2].waiting != nil }
        let cancelledEngine = AetherPlaybackEngine.instances[2]
        cancelledStart.cancel()
        try await waitUntil { cancelledEngine.stopped && cancelledModel.playbackEngine == nil }
        cancelledEngine.complete()
        await cancelledStart.value
        precondition(cancelledModel.playbackEngine == nil, "Cancelled startup cannot resurrect playback")

        // SwiftUI cancels its view task on disappearing. Already-started playback
        // must remain alive for the iOS view's explicit PiP ownership decision.
        let pipModel = PlaybackViewModel(source: .init(kind: .movie), item: MediaItem(), resumeProgress: nil)
        SubtitleService.shared.delay = true
        let pipStart = Task { await pipModel.startPlayback() }
        try await waitUntil { AetherPlaybackEngine.instances.count == 4 && AetherPlaybackEngine.instances[3].waiting != nil }
        let pipEngine = AetherPlaybackEngine.instances[3]
        pipEngine.complete()
        try await waitUntil { SubtitleService.shared.waiting != nil }
        pipStart.cancel()
        try await Task.sleep(for: .milliseconds(30))
        precondition(!pipEngine.stopped && pipModel.playbackEngine === pipEngine, "Cancelling subtitle work must preserve started PiP playback")
        SubtitleService.shared.waiting?.resume(); SubtitleService.shared.waiting = nil
        await pipStart.value
        pipModel.stopForDisappear()
        SubtitleService.shared.delay = false

        let timeoutModel = PlaybackViewModel(source: .init(kind: .movie), item: nil, resumeProgress: nil)
        let timeoutStart = Task { await timeoutModel.startPlayback() }
        try await waitUntil { AetherPlaybackEngine.instances.count == 5 && AetherPlaybackEngine.instances[4].waiting != nil }
        let stalled = AetherPlaybackEngine.instances[4]
        try await Task.sleep(for: .seconds(21))
        precondition(stalled.stopped && timeoutModel.playbackEngine == nil && timeoutModel.playbackError != nil,
                     "Timeout must release playback and show an error without waiting for the stalled dependency")
        stalled.complete()
        await timeoutStart.value
        print("PASS: duplicate starts, stale completions, cancellation, teardown, PiP ownership and independent 20-second startup deadline")
    }
}
