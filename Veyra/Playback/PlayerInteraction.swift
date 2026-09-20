import Foundation
#if canImport(Combine)
    import Combine
#endif

// One worker owns all engine seeks. Repeated remote input only replaces its
// pending destination; it never cancels an in-flight seek to start another one.
@MainActor final class VeyraPlayerSeekController {
    typealias Seek = @MainActor (Double) async -> Void

    #if canImport(Combine)
        @Published private(set) var previewTime: Double?
        @Published private(set) var isSeeking = false
    #else
        // The same queue can be tested with Swift on hosts without Apple SDKs.
        private(set) var previewTime: Double?
        private(set) var isSeeking = false
    #endif

    private let debounce: Duration
    private var worker: Task<Void, Never>?
    private var pending: Request?
    private var revision: UInt64 = 0

    private struct Request {
        let revision: UInt64
        let target: Double
        let readyAt: ContinuousClock.Instant
        let perform: Seek
    }

    init(debounce: Duration = .milliseconds(180)) { self.debounce = max(.zero, debounce) }

    @discardableResult func request(
        by offset: Double, currentTime: Double, duration: Double, perform: @escaping Seek
    ) -> Bool {
        let base = previewTime ?? currentTime
        guard duration.isFinite, duration > 0, base.isFinite, offset.isFinite, offset != 0 else {
            return false
        }

        let target = min(duration, max(0, base + offset))
        // At the start/end, holding a direction must not keep postponing an
        // otherwise identical request forever.
        guard pending?.target != target else { return false }

        revision &+= 1
        previewTime = target
        pending = Request(
            revision: revision, target: target, readyAt: ContinuousClock.now.advanced(by: debounce),
            perform: perform)
        startWorkerIfNeeded()
        return true
    }

    func cancel() {
        pending = nil
        previewTime = nil
        worker?.cancel()
        // Keep ownership until the awaited operation returns. An engine may
        // ignore cancellation; even a new request must wait for that operation.
    }

    private func startWorkerIfNeeded() {
        guard worker == nil, pending != nil else { return }
        worker = Task { @MainActor [weak self] in await self?.drain() }
    }

    private func drain() async {
        defer {
            isSeeking = false
            worker = nil
            // A request can arrive after cancel() while an old engine call is
            // still returning. Start its worker only after releasing ownership.
            startWorkerIfNeeded()
        }

        while !Task.isCancelled, let request = pending {
            if ContinuousClock.now < request.readyAt {
                do { try await Task.sleep(until: request.readyAt, clock: .continuous) } catch {
                    return
                }
                // Read the latest destination/deadline after every suspension.
                continue
            }

            isSeeking = true
            await request.perform(request.target)
            isSeeking = false

            guard !Task.isCancelled else { return }
            // Compare request identity, not Double values: A -> B -> A is still
            // newer input and must not be cleared by completion of the first A.
            if pending?.revision == request.revision {
                pending = nil
                previewTime = nil
            }
        }
    }
}

#if canImport(Combine)
    extension VeyraPlayerSeekController: ObservableObject {}
#endif

// Presentation-only state. No menu operation can stop/reload playback or finish
// the Trakt session; only exitPlayer is forwarded to PlayerView's dismiss action.
struct VeyraPlayerPresentation {
    enum Panel: Equatable {
        case subtitles
        case audio
        case speed
    }

    enum BackAction: Equatable {
        case closedPanel(Panel)
        case hidControls
        case exitPlayer
    }

    private(set) var controlsVisible = true
    private(set) var panel: Panel?

    mutating func open(_ panel: Panel) {
        self.panel = panel
        controlsVisible = true
    }

    @discardableResult mutating func close(_ panel: Panel) -> Bool {
        guard self.panel == panel else { return false }
        self.panel = nil
        controlsVisible = true
        return true
    }

    mutating func revealControls() { controlsVisible = true }

    @discardableResult mutating func hideControls() -> Bool {
        guard panel == nil else { return false }
        controlsVisible = false
        return true
    }

    mutating func handleBack() -> BackAction {
        if let panel {
            self.panel = nil
            controlsVisible = true
            return .closedPanel(panel)
        }
        if controlsVisible {
            controlsVisible = false
            return .hidControls
        }
        return .exitPlayer
    }
}

enum VeyraPlayerControl: Hashable {
    case surface
    case subtitles
    case audio
    case speed
    case nextEpisode
    case cancelNextEpisode
    case skipSegment
    case timeline
    case play
    case backward
    case forward

    func horizontalNeighbor(forward: Bool, canSeek: Bool) -> Self {
        let row: [Self] =
            canSeek
            ? [.subtitles, .backward, .play, .forward, .audio, .speed]
            : [.subtitles, .play, .audio, .speed]
        guard let index = row.firstIndex(of: self) else { return .play }
        return row[min(row.count - 1, max(0, index + (forward ? 1 : -1)))]
    }
}
