import Foundation
import SwiftUI
import Combine
import AetherEngine

@MainActor
final class PlaybackViewModel: ObservableObject {
    @Published private(set) var playbackEngine: AetherPlaybackEngine?
    @Published private(set) var playbackError: String?

    // "Kijk je nog?" -- na lange inactiviteit (geen tik/toets/remote-druk)
    // vraagt de speler dit, en stopt vanzelf als er geen reactie komt.
    // `registerActivity()` wordt aangeroepen vanuit elke bestaande
    // interactie in de platform-spelers (tik, knop, remote-commando).
    @Published private(set) var showStillWatchingPrompt = false
    private var lastActivityAt = Date()
    private var idleMonitorTask: Task<Void, Never>?
    private static let idleTimeout: TimeInterval = 4 * 60 * 60
    private static let idlePromptGrace: TimeInterval = 60

    private var tracker: TraktPlaybackTracker?
    private var veyraHubTracker: VeyraHubPlaybackTracker?
    private var localTracker: VeyraLocalWatchTracker?
    private var recorderCleanupTracker: VeyraHubRecorderCleanupTracker?
    private var videoRecoveryTask: Task<Void, Never>?
    private var startupTask: Task<Void, Never>?
    private var sessionID: UUID?
    private var startupCompleted = false

    private let source: PlayableSource
    private let item: MediaItem?
    private let resumeProgress: Double?

    // Live-zender die niet start: automatisch dezelfde zender bij een
    // ANDERE ingestelde IPTV-playlist proberen (zie
    // `LiveChannelFallbackResolver`), precies één keer per sessie, vóór de
    // gewone foutmelding ("Opnieuw proberen") getoond wordt.
    private var activeSource: PlayableSource!
    private var attemptedLiveFallback = false

    // Sommige IPTV/live-TV-bronnen laten de onderliggende netwerkverbinding
    // hangen (time-outs bij de probe/handshake) zonder dat AetherEngine dat
    // ooit als fout naar boven gooit — dat gaf een permanent zwart scherm
    // zonder foutmelding. Met deze timeout krijgt `engine.play(...)` een
    // hard plafond, zodat zo'n hang alsnog als duidelijke afspeelfout
    // eindigt (met retry-knop) in plaats van oneindig te blijven hangen.
    private static let playbackStartTimeout: TimeInterval = 20

    nonisolated init(source: PlayableSource, item: MediaItem?, resumeProgress: Double?) {
        self.source = source
        self.item = item
        self.resumeProgress = resumeProgress
        self.activeSource = source
    }

    func startPlayback() async {
        // SwiftUI may enter .task more than once while retaining a player view.
        guard startupTask == nil, playbackEngine == nil else { return }
        let session = UUID()
        sessionID = session
        startupCompleted = false
        playbackError = nil
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.performStart(session: session)
        }
        startupTask = task
        await withTaskCancellationHandler {
            await task.value
        } onCancel: { [self] in
            task.cancel()
            Task { @MainActor in
                guard self.sessionID == session, !self.startupCompleted else { return }
                self.stopForDisappear()
            }
        }
        if sessionID == session { startupTask = nil }
    }

    private func performStart(session: UUID) async {
        guard sessionID == session, !Task.isCancelled else { return }
        registerActivity()
        startIdleMonitor()
        let playSource = activeSource!
        // An independent deadline can stop the engine immediately, even when a
        // dependency's load operation is slow to acknowledge cancellation.
        let deadline = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(Self.playbackStartTimeout))
            guard !Task.isCancelled, self?.sessionID == session else { return }
            self?.stopForDisappear()
            self?.playbackError = PlaybackTimeoutError(isLiveTV: playSource.kind == .liveTV).localizedDescription
        }
        defer { deadline.cancel() }
        var startedEngine: AetherPlaybackEngine?
        do {
            SubtitleService.shared.reset()
            let engine = try AetherPlaybackEngine()
            startedEngine = engine
            playbackEngine = engine
            if let item {
                tracker = TraktPlaybackTracker(item: item, engine: engine.engine)
                localTracker = VeyraLocalWatchTracker(item: item, engine: engine.engine)
            }
            if let sync = playSource.progressSync {
                veyraHubTracker = VeyraHubPlaybackTracker(sync: sync, engine: engine.engine)
            }
            if let cleanup = playSource.recorderCleanup {
                recorderCleanupTracker = VeyraHubRecorderCleanupTracker(cleanup: cleanup, engine: engine.engine)
            }
            let progress = await Self.resolveResumeProgress(source: playSource, item: item, fallback: resumeProgress)
            try Task.checkCancellation()
            guard sessionID == session else { throw CancellationError() }
            try await engine.play(playSource, resumeProgress: progress)
            try Task.checkCancellation()
            guard sessionID == session, playbackEngine === engine else { throw CancellationError() }
            deadline.cancel()
            startupCompleted = true
            if playSource.kind == .liveTV || playSource.kind == .iptvVOD {
                monitorFirstVideoFrame(engine)
            }
            if let item {
                await SubtitleService.shared.loadExternalSubtitles(for: item, into: engine.engine)
            }
        } catch {
            deadline.cancel()
            // A stale completion may clean up its own engine, never the new session.
            startedEngine?.stop()
            guard sessionID == session else { return }
            if Task.isCancelled || error is CancellationError {
                stopForDisappear()
                return
            }
            stopPlaybackResources()
            if playSource.kind == .liveTV, !attemptedLiveFallback {
                let fallback = await LiveChannelFallbackResolver.resolve(after: playSource)
                guard sessionID == session, !Task.isCancelled else { return }
                if let fallback {
                    attemptedLiveFallback = true
                    activeSource = fallback
                    await performStart(session: session)
                    return
                }
            }
            playbackError = error.localizedDescription
        }
    }

    /// Opnieuw proberen na een afspeelfout, zonder het scherm te sluiten.
    func retry() async {
        stopForDisappear()
        playbackError = nil
        await startPlayback()
    }

    func stopForDisappear() {
        sessionID = nil
        startupTask?.cancel()
        startupTask = nil
        stopPlaybackResources()
    }

    private func stopPlaybackResources() {
        idleMonitorTask?.cancel()
        idleMonitorTask = nil
        videoRecoveryTask?.cancel()
        videoRecoveryTask = nil
        tracker?.finish()
        veyraHubTracker?.finish()
        localTracker?.finish()
        recorderCleanupTracker?.finish()
        let ownedSubtitles = playbackEngine?.isActiveSession == true
        playbackEngine?.stop()
        if ownedSubtitles { SubtitleService.shared.reset() }

        tracker = nil
        veyraHubTracker = nil
        localTracker = nil
        recorderCleanupTracker = nil
        playbackEngine = nil
    }

    // MARK: - "Kijk je nog?"

    /// Door elke bestaande interactie in de spelers aangeroepen (tik, knop,
    /// remote-commando) -- reset de inactiviteitsklok en sluit een eventuele
    /// "Kijk je nog?"-vraag meteen af.
    func registerActivity() {
        lastActivityAt = Date()
        if showStillWatchingPrompt { showStillWatchingPrompt = false }
    }

    private func startIdleMonitor() {
        idleMonitorTask?.cancel()
        idleMonitorTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard let self, !Task.isCancelled else { return }
                self.checkIdle()
            }
        }
    }

    private func checkIdle() {
        let idleFor = Date().timeIntervalSince(lastActivityAt)
        if showStillWatchingPrompt {
            if idleFor >= Self.idleTimeout + Self.idlePromptGrace {
                idleMonitorTask?.cancel()
                idleMonitorTask = nil
                stopForDisappear()
                playbackError = "Afspelen gestopt: geen reactie op \"Kijk je nog?\"."
            }
        } else if idleFor >= Self.idleTimeout {
            showStillWatchingPrompt = true
        }
    }

    func handleScenePhaseChange(_ phase: ScenePhase) {
        if phase != .active {
            stopForDisappear()
        }
    }

    #if os(iOS) || os(macOS) || os(tvOS)
    private func monitorFirstVideoFrame(_ playback: AetherPlaybackEngine) {
        videoRecoveryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard let self, !Task.isCancelled,
                  self.playbackEngine === playback,
                  !playback.engine.hasFirstFrameReadyForDisplay else { return }

            if playback.engine.playbackBackend == .native {
                do {
                    try await playback.engine.reloadAtCurrentPosition {
                        $0.preferredDecodePath = .software
                    }
                    guard !Task.isCancelled, self.playbackEngine === playback else { return }
                    playback.engine.play()
                } catch {
                    // De bestaande sessie blijft beschikbaar als omschakelen
                    // niet mogelijk is; de uiteindelijke melding volgt hieronder.
                }
            }

            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled,
                  self.playbackEngine === playback,
                  !playback.engine.hasFirstFrameReadyForDisplay else { return }
            self.stopForDisappear()
            self.playbackError = "De stream start, maar geeft geen videobeeld. Probeer een andere zender of bron."
        }
    }
    #endif

    // MARK: - VeyraHub resume

    /// Prefers VeyraHub's own stored resume position (synced across every
    /// device signed into the same account) over the Trakt-derived
    /// `resumeProgress` this view model was handed, for a source that came
    /// from a VeyraHub server. `AetherPlaybackEngine` expects a 0–100
    /// percentage (see `resolveStartPosition`), so a stored
    /// positionSeconds/durationSeconds pair is converted here rather than
    /// changing that engine-side contract for one source type. Falls back
    /// to `fallback` whenever VeyraHub has no stored position, or the
    /// lookup fails — a resume-position lookup must never block or break
    /// starting playback.
    private static func resolveResumeProgress(
        source: PlayableSource,
        item: MediaItem?,
        fallback: Double?
    ) async -> Double? {
        if let item, TraktStore.shared.wasProgressReset(for: item) {
            if let sync = source.progressSync {
                let client = VeyraHubNativeClient(account: sync.account)
                do {
                    let previous = try? await client.progress(type: sync.mediaType, id: sync.mediaID)
                    try await client.setProgress(
                        type: sync.mediaType,
                        id: sync.mediaID,
                        positionSeconds: 0,
                        durationSeconds: max(1, previous?.durationSeconds ?? 1)
                    )
                    TraktStore.shared.clearProgressReset(for: item)
                } catch {
                    // Blijf de oude Hub-positie negeren tot de reset daar lukt.
                }
            }
            return nil
        }
        guard let sync = source.progressSync else { return fallback }

        do {
            let progress = try await VeyraHubNativeClient(account: sync.account)
                .progress(type: sync.mediaType, id: sync.mediaID)

            guard
                progress.found,
                let position = progress.positionSeconds,
                let duration = progress.durationSeconds,
                duration > 0, position > 0
            else {
                return fallback
            }

            return min(100, max(0, position / duration * 100))
        } catch {
            print("[PlaybackViewModel] VeyraHub resume-opzoeking mislukt: \(error.localizedDescription)")
            return fallback
        }
    }

    // MARK: - Timeout

    private struct PlaybackTimeoutError: LocalizedError {
        /// Live TV/IPTV-bronnen hangen bij een time-out vaak niet door een netwerkprobleem,
        /// maar omdat het IPTV-account maar één gelijktijdige stream toestaat en er elders
        /// al een kanaal open staat -- de provider stuurt dan geen foutmelding, gewoon stilte.
        var isLiveTV: Bool = false
        var errorDescription: String? {
            if isLiveTV {
                return "Dit kanaal reageert niet. Vaak komt dit doordat je IPTV-account maar één gelijktijdige stream toestaat en er al een ander toestel aan het kijken is. Sluit de stream op je andere toestel, of controleer anders je internetverbinding."
            }
            return "De stream reageert niet. Controleer je internetverbinding of probeer het later opnieuw."
        }
    }

}
