import AppKit
import SwiftUI
import AetherEngine

nonisolated struct MediaItem: Equatable {
    enum Kind { case movie, series }
    var type: Kind = .series
    var seasonNumber: Int? = 1
    var episodeNumber: Int? = 1
}
nonisolated enum PlaybackSettingsDefaults {
    static let autoPlayNextEpisodeKey = "playback.autoPlayNextEpisode"
}
@MainActor final class EndProbe: ObservableObject {
    @Published var resolved = false
    @Published var next: MediaItem?
    @Published var cancelled = false
    var returns = 0
    var advances = 0
}
private struct EndProbeView: View {
    let engine: AetherEngine
    @ObservedObject var probe: EndProbe
    let item: MediaItem
    let live: Bool
    var body: some View {
        Text("Player")
            .veyraEpisodeCompletion(
                engine: engine, item: item, isLive: live,
                nextEpisode: probe.next, nextEpisodeResolved: probe.resolved,
                autoAdvanceCancelled: probe.cancelled,
                onNext: { _ in probe.advances += 1 }, onReturn: { probe.returns += 1 }
            )
    }
}
@main struct EpisodeCompletionChecks {
    @MainActor static func settle() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.12))
    }
    @MainActor static func main() {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let suiteName = "VeyraEpisodeCompletionTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let host = NSHostingView(rootView: AnyView(EmptyView()))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 700, height: 440),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        window.orderBack(nil)
        func mount(autoplay: Bool, item: MediaItem = MediaItem(), live: Bool = false) -> (AetherEngine, EndProbe) {
            defaults.set(autoplay, forKey: PlaybackSettingsDefaults.autoPlayNextEpisodeKey)
            let engine = AetherEngine(), probe = EndProbe()
            host.rootView = AnyView(EndProbeView(engine: engine, probe: probe, item: item, live: live)
                .defaultAppStorage(defaults).id(UUID()))
            settle()
            return (engine, probe)
        }
        let (off, offProbe) = mount(autoplay: false)
        off.state = .playing; settle()
        off.state = .paused; settle()
        off.state = .idle; settle()
        precondition(offProbe.returns == 0, "Pause/stop cannot masquerade as episode completion")
        off.state = .ended; settle()
        precondition(offProbe.returns == 1 && offProbe.advances == 0,
                     "Autoplay off must return without waiting for next-episode metadata")
        off.state = .playing; settle(); off.state = .ended; settle()
        precondition(offProbe.returns == 1, "Repeated EOF cannot pop the list itself")

        let (on, onProbe) = mount(autoplay: true)
        on.state = .ended; settle()
        precondition(onProbe.returns == 0 && onProbe.advances == 0)
        onProbe.next = MediaItem(episodeNumber: 2); onProbe.resolved = true; settle()
        precondition(onProbe.advances == 1 && onProbe.returns == 0,
                     "EOF must advance when autoplay is on, even without a credits countdown")

        let (last, lastProbe) = mount(autoplay: true)
        lastProbe.resolved = true; settle(); last.state = .ended; settle()
        precondition(lastProbe.returns == 1 && lastProbe.advances == 0)

        let (cancelled, cancelProbe) = mount(autoplay: true)
        cancelProbe.cancelled = true; settle(); cancelled.state = .ended; settle()
        precondition(cancelProbe.returns == 1 && cancelProbe.advances == 0)

        let (live, liveProbe) = mount(autoplay: false, live: true)
        live.state = .ended; settle(); precondition(liveProbe.returns == 0)
        let (movie, movieProbe) = mount(autoplay: false, item: MediaItem(type: .movie))
        movie.state = .ended; settle(); precondition(movieProbe.returns == 0)

        window.orderOut(nil)
        print("PASS: native SwiftUI EOF, autoplay off, delayed next metadata, autoplay on, final episode, cancelled countdown, duplicate EOF, live/movie exclusions")
    }
}
