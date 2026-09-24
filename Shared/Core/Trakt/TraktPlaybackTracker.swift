import Foundation
import Combine
import AetherEngine

@MainActor
final class TraktPlaybackTracker {
    private let item: MediaItem
    private let store: TraktStore
    private weak var engine: AetherEngine?
    private var subscriptions: Set<AnyCancellable> = []
    private var lastEvent: String?
    private var hasPlayed = false
    private var finished = false
    private var lastProgress: Double = 0

    init(item: MediaItem, engine: AetherEngine, store: TraktStore? = nil) {
        self.item = item
        self.engine = engine
        self.store = store ?? .shared
        engine.$state.sink { [weak self] state in self?.changed(state) }.store(in: &subscriptions)
        Timer.publish(every: 1, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in
                guard let self, let engine = self.engine else { return }
                self.sample()
                // Duration may only become known after the playing transition.
                if engine.state == .playing { self.changed(.playing) }
            }.store(in: &subscriptions)
    }

    private func sample() {
        guard let engine, let progress = Self.progress(time: engine.currentTime, duration: engine.duration) else { return }
        lastProgress = progress
    }

    static func progress(time: Double, duration: Double) -> Double? {
        guard time.isFinite, duration.isFinite, duration > 0 else { return nil }
        return min(100, max(0, time / duration * 100))
    }

    private func changed(_ state: PlaybackState) {
        guard !finished else { return }
        sample()
        switch state {
        case .playing:
            guard let engine, engine.duration.isFinite, engine.duration > 0 else {
                print("[TraktTracker] .playing genegeerd (duration nog onbekend): duration=\(engine?.duration ?? -1)")
                return
            }
            hasPlayed = true
            if lastEvent != "start" {
                print("[TraktTracker] -> scrobble(start) item=\(item.title) progress=\(lastProgress) duration=\(engine.duration)")
                store.scrobble("start", item: item, progress: lastProgress)
                lastEvent = "start"
            }
        case .paused:
            guard hasPlayed, lastEvent != "pause" else {
                print("[TraktTracker] .paused genegeerd hasPlayed=\(hasPlayed) lastEvent=\(lastEvent ?? "nil")")
                return
            }
            print("[TraktTracker] -> scrobble(pause) item=\(item.title) progress=\(lastProgress)")
            store.scrobble("pause", item: item, progress: lastProgress)
            lastEvent = "pause"
        case .ended:
            guard hasPlayed else {
                print("[TraktTracker] .ended genegeerd, hasPlayed=false (start is dus nooit gelukt)")
                return
            }
            lastProgress = 100
            print("[TraktTracker] .ended -> finish(100)")
            finish(samplePosition: false)
        case .error:
            print("[TraktTracker] .error -> finish()")
            finish()
        case .idle, .loading, .seeking:
            break
        @unknown default: break
        }
    }

    func finish(samplePosition: Bool = true) {
        guard !finished else { return }
        if samplePosition { sample() }
        finished = true
        subscriptions.removeAll()
        if hasPlayed {
            print("[TraktTracker] -> scrobble(stop) item=\(item.title) progress=\(lastProgress)")
            store.scrobble("stop", item: item, progress: lastProgress)
        } else {
            print("[TraktTracker] finish() maar hasPlayed=false, geen stop verstuurd. item=\(item.title)")
        }
    }
}
