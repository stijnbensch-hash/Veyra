import SwiftUI
import AetherEngine
import AppKit

struct PlayerView: View {
    let source: PlayableSource
    var item: MediaItem? = nil
    var resumeProgress: Double? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.veyraEpisodeReturn) private var returnToEpisodes
    @State private var finishingEpisode = false
    @State private var nextEpisodeResolved = false
    @State private var nextCountdownCancelled = false
    @StateObject private var viewModel: PlaybackViewModel
    @StateObject private var pip = MacPictureInPictureController()
    @StateObject private var fullscreen = MacPlayerWindowController()
    @State private var nextEpisode: MediaItem?
    @State private var nextRequest: MacNextPlaybackRequest?
    @State private var resolvingNextEpisode = false

    init(source: PlayableSource, item: MediaItem? = nil, resumeProgress: Double? = nil) {
        self.source = source
        self.item = item
        self.resumeProgress = resumeProgress
        _viewModel = StateObject(wrappedValue: PlaybackViewModel(
            source: source, item: item, resumeProgress: resumeProgress
        ))
    }

    var body: some View {
        ZStack {
            Color.black

            if let message = viewModel.playbackError {
                ContentUnavailableView("Afspelen niet mogelijk", systemImage: "play.slash", description: Text(message))
                    .overlay(alignment: .top) {
                        if source.kind == .liveTV {
                            IPTVLiveProviderStatusBadge(source: source, item: item)
                                .padding()
                        }
                    }
                    .overlay(alignment: .bottom) {
                        Button("Opnieuw proberen") { Task { await viewModel.retry() } }
                            .padding()
                    }
            } else if let playbackEngine = viewModel.playbackEngine {
                MacPlayerSurface(
                    engine: playbackEngine.engine,
                    title: item?.title ?? source.name,
                    item: item,
                    source: source,
                    nextEpisode: nextEpisode,
                    nextEpisodeResolved: nextEpisodeResolved,
                    countdownCancelled: $nextCountdownCancelled,
                    onEpisodeFinished: finishEpisode,
                    resolvingNextEpisode: resolvingNextEpisode,
                    onPlayNextEpisode: playNextEpisode,
                    pip: pip,
                    fullscreen: fullscreen,
                    onUserActivity: { viewModel.registerActivity() }
                )
            } else {
                ProgressView("Veyra Player starten…")
                    .controlSize(.large)
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("Sluiten", systemImage: "xmark") { dismiss() }
            }
        }
        .alert("Kijk je nog?", isPresented: Binding(
            get: { viewModel.showStillWatchingPrompt },
            set: { if !$0 { viewModel.registerActivity() } }
        )) {
            Button("Ja, doorgaan") { viewModel.registerActivity() }
        } message: {
            Text("Afspelen stopt zo als er geen reactie komt.")
        }
        .task { await viewModel.startPlayback() }
        .task(id: item?.id) {
            nextEpisodeResolved = false
            let resolved = await NextEpisodeResolver.resolve(after: item)
            guard !Task.isCancelled else { return }
            nextEpisode = resolved
            nextEpisodeResolved = true
            // Spec §41: alvast de skip-markers van de volgende aflevering
            // ophalen zodat de skip-knop meteen klaarstaat bij autoplay.
            if let nextEpisode {
                let nextIdentity = VeyraSkipMediaIdentity(
                    tmdbID: nextEpisode.tmdbID,
                    imdbID: nextEpisode.imdbID,
                    season: nextEpisode.type == .series ? nextEpisode.seasonNumber : nil,
                    episode: nextEpisode.type == .series ? nextEpisode.episodeNumber : nil,
                    duration: nil
                )
                await VeyraSkipSegmentStore.shared.prefetch(nextIdentity)
            }
        }
        .onDisappear {
            if fullscreen.mode == .floating {
                MacFloatingPlayerSession.shared.keep(viewModel: viewModel, controller: fullscreen)
                return
            }
            fullscreen.close()
            if pip.keepsPlaybackAlive {
                MacPictureInPictureSession.shared.keep(viewModel: viewModel, pip: pip)
            } else {
                viewModel.stopForDisappear()
            }
        }
        .navigationDestination(item: $nextRequest) { request in
            Group {
                if let source = request.source {
                    PlayerView(source: source, item: request.item)
                } else {
                    SourceSelectionView(item: request.item)
                }
            }
            .environment(\.veyraEpisodeReturn, returnToEpisodes ?? { dismiss() })
        }
        .frame(minWidth: 680, minHeight: 440)
    }

    private func finishEpisode() {
        guard !finishingEpisode, !resolvingNextEpisode, nextRequest == nil else { return }
        finishingEpisode = true
        fullscreen.close()
        pip.stop()
        viewModel.stopForDisappear()
        if let returnToEpisodes { returnToEpisodes() }
        else { dismiss() }
    }

    private func playNextEpisode(_ next: MediaItem) {
        guard !finishingEpisode, !resolvingNextEpisode, nextRequest == nil else { return }
        fullscreen.close()
        pip.stop()
        // Finish the previous episode's tracking before opening its successor.
        viewModel.stopForDisappear()
        resolvingNextEpisode = true
        Task {
            let source = await NextEpisodeSourceResolver.resolve(matching: self.source, for: next)
            resolvingNextEpisode = false
            nextRequest = MacNextPlaybackRequest(item: next, source: source)
        }
    }
}

private struct MacNextPlaybackRequest: Identifiable, Hashable {
    let id = UUID()
    let item: MediaItem
    let source: PlayableSource?
}

@MainActor
final class MacPlayerWindowController: NSObject, ObservableObject, NSWindowDelegate {
    enum Mode { case normal, fullscreen, floating }

    @Published private(set) var mode: Mode = .normal
    var isPresented: Bool { mode != .normal }
    var onClosed: (() -> Void)?

    private var window: NSWindow?

    // Menubalk (en Dock) in fullscreen: automatisch verbergen, en even
    // tevoorschijn laten komen zodra de muis beweegt of een toets wordt
    // ingedrukt -- daarna, bij inactiviteit, weer verbergen. Standaard
    // AppKit-fullscreen toont de menubalk enkel bij hover helemaal bovenaan
    // het scherm; met `NSApp.presentationOptions` sturen we dat hier zelf
    // aan zodat elke muisbeweging of toetsaanslag volstaat.
    private var menuBarEventMonitor: Any?
    private var menuBarHideWorkItem: DispatchWorkItem?

    private func startAutoHidingMenuBar() {
        NSApp.presentationOptions = [.autoHideMenuBar, .autoHideDock]
        guard menuBarEventMonitor == nil else { return }
        menuBarEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .keyDown]) { [weak self] event in
            self?.revealMenuBarBriefly()
            return event
        }
    }

    private func revealMenuBarBriefly() {
        guard mode == .fullscreen else { return }
        NSApp.presentationOptions = []
        menuBarHideWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.mode == .fullscreen else { return }
            NSApp.presentationOptions = [.autoHideMenuBar, .autoHideDock]
        }
        menuBarHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: workItem)
    }

    private func stopAutoHidingMenuBar() {
        if let menuBarEventMonitor { NSEvent.removeMonitor(menuBarEventMonitor) }
        menuBarEventMonitor = nil
        menuBarHideWorkItem?.cancel()
        menuBarHideWorkItem = nil
        NSApp.presentationOptions = []
    }

    func present<Content: View>(title: String, content: Content) {
        guard window == nil else { return }

        let frame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.collectionBehavior = [.fullScreenPrimary]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = NSHostingView(rootView: AnyView(content))

        self.window = window
        mode = .fullscreen
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // AppKit kan pas naar volledig scherm nadat het venster zichtbaar is.
        DispatchQueue.main.async { [weak self, weak window] in
            guard let self, let window, self.window === window else { return }
            window.toggleFullScreen(nil)
        }
    }

    func presentFloating<Content: View>(title: String, content: Content) {
        guard window == nil else { return }

        let screen = NSApp.keyWindow?.screen ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let width: CGFloat = 440
        let height: CGFloat = 290
        let panel = NSPanel(
            contentRect: NSRect(x: visibleFrame.maxX - width - 20, y: visibleFrame.minY + 20,
                                width: width, height: height),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = title
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.minSize = NSSize(width: 320, height: 210)
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: AnyView(content))

        window = panel
        mode = .floating
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func exit() {
        guard let window else { return }
        stopAutoHidingMenuBar()
        if window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)
        } else {
            window.close()
        }
    }

    func update<Content: View>(content: Content) {
        guard mode == .fullscreen else { return }
        guard let hostingView = window?.contentView as? NSHostingView<AnyView> else { return }
        hostingView.rootView = AnyView(content)
    }

    func close() {
        stopAutoHidingMenuBar()
        window?.close()
        window = nil
        mode = .normal
    }

    func windowDidEnterFullScreen(_ notification: Notification) {
        if mode == .fullscreen { startAutoHidingMenuBar() }
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        stopAutoHidingMenuBar()
        if mode == .fullscreen { close() }
    }

    func windowDidFailToEnterFullScreen(_ window: NSWindow) {
        stopAutoHidingMenuBar()
        close()
    }

    func windowWillClose(_ notification: Notification) {
        stopAutoHidingMenuBar()
        window = nil
        mode = .normal
        let callback = onClosed
        onClosed = nil
        callback?()
    }
}

@MainActor
private final class MacPictureInPictureSession {
    static let shared = MacPictureInPictureSession()

    private var sessions: [ObjectIdentifier: (PlaybackViewModel, MacPictureInPictureController)] = [:]

    func keep(viewModel: PlaybackViewModel, pip: MacPictureInPictureController) {
        let id = ObjectIdentifier(pip)
        sessions[id] = (viewModel, pip)
        pip.onEnded = { [weak self] in
            guard let session = self?.sessions.removeValue(forKey: id) else { return }
            session.0.stopForDisappear()
            session.1.onEnded = nil
        }
    }
}

@MainActor
private final class MacFloatingPlayerSession {
    static let shared = MacFloatingPlayerSession()

    private var sessions: [ObjectIdentifier: (PlaybackViewModel, MacPlayerWindowController)] = [:]

    func keep(viewModel: PlaybackViewModel, controller: MacPlayerWindowController) {
        let id = ObjectIdentifier(controller)
        sessions[id] = (viewModel, controller)
        controller.onClosed = { [weak self] in
            guard let session = self?.sessions.removeValue(forKey: id) else { return }
            session.0.stopForDisappear()
        }
    }
}

private struct MacCompactPlayerSurface: View {
    @ObservedObject var engine: AetherEngine
    let title: String
    @ObservedObject var controller: MacPlayerWindowController

    var body: some View {
        ZStack(alignment: .bottom) {
            AetherPlayerSurface(engine: engine)
            MacSubtitleOverlay(engine: engine)
                .allowsHitTesting(false)

            HStack(spacing: 14) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Button(engine.state == .playing ? "Pauzeren" : "Afspelen",
                       systemImage: engine.state == .playing ? "pause.fill" : "play.fill") {
                    if engine.state == .playing { engine.pause() } else { engine.play() }
                }
                Button("Terug naar speler", systemImage: "arrow.down.right.and.arrow.up.left") {
                    controller.close()
                }
            }
            .buttonStyle(.borderless)
            .padding(12)
            .background(.black.opacity(0.8))
        }
        .foregroundStyle(.white)
        .background(.black)
    }
}

private struct MacPlayerSurface: View {
    @ObservedObject var engine: AetherEngine
    let title: String
    let item: MediaItem?
    let source: PlayableSource
    let nextEpisode: MediaItem?
    let nextEpisodeResolved: Bool
    @Binding var countdownCancelled: Bool
    let onEpisodeFinished: () -> Void
    let resolvingNextEpisode: Bool
    let onPlayNextEpisode: (MediaItem) -> Void
    @ObservedObject var pip: MacPictureInPictureController
    @ObservedObject var fullscreen: MacPlayerWindowController
    var isFullscreenPresentation = false
    var onUserActivity: () -> Void = {}

    // Actieve/maximale gelijktijdige verbindingen van de Xtream-provider
    // waarmee deze IPTV-stream loopt (bv. "1/2") -- enkel voor IPTV, zie de
    // iOS/tvOS-spelers voor dezelfde aanpak.
    @State private var connectionStatus: XtreamConnectionStatus?

    private var isIPTV: Bool {
        source.kind == .liveTV || source.kind == .iptvVOD
    }

    private func loadConnectionStatus() async {
        guard isIPTV else { return }
        let store = IPTVConfigurationStore()
        guard let activeID = try? store.activeProviderID(),
              let providers = try? store.loadProviders(),
              let provider = providers.first(where: { $0.id == activeID }),
              case .xtream(let configuration) = provider.configuration
        else { return }
        connectionStatus = try? await XtreamClient(configuration: configuration).connectionStatus()
    }

    @State private var seekPosition: Double = 0
    @State private var isSeeking = false
    @State private var showOpenSubtitles = false
    // Uniform Veyra-model, bronneutraal (zie Shared/Playback/SkipSegments/) --
    // deze view weet niet dat TheIntroDB de bron is.
    @State private var skipSegments: [VeyraSkipSegment] = []
    @State private var autoSkippedSegmentIDs: Set<String> = []
    @State private var countdownRemaining: Int?
    @State private var countdownTask: Task<Void, Never>?
    @State private var playbackRate: Float = 1

    @AppStorage(PlaybackSettingsDefaults.showSkipIntroButtonKey) private var showSkipIntro = true
    @AppStorage(PlaybackSettingsDefaults.autoSkipIntroKey) private var autoSkipIntro = false
    @AppStorage(PlaybackSettingsDefaults.showSkipRecapButtonKey) private var showSkipRecap = true
    @AppStorage(PlaybackSettingsDefaults.showSkipCreditsButtonKey) private var showSkipCredits = true
    @AppStorage(PlaybackSettingsDefaults.showSkipPreviewButtonKey) private var showSkipPreview = true
    @AppStorage(PlaybackSettingsDefaults.autoSkipRecapKey) private var autoSkipRecap = false
    @AppStorage(PlaybackSettingsDefaults.autoSkipCreditsKey) private var autoSkipCredits = false
    @AppStorage(PlaybackSettingsDefaults.autoSkipPreviewKey) private var autoSkipPreview = false
    @AppStorage(PlaybackSettingsDefaults.autoPlayNextEpisodeKey) private var autoPlayNextEpisode = true
    @AppStorage(PlaybackSettingsDefaults.autoPlayNextCountdownEnabledKey) private var countdownEnabled = true
    @AppStorage(PlaybackSettingsDefaults.countdownDurationKey)
    private var countdownDurationRaw = PlaybackCountdownDuration.ten.rawValue

    private var canSeek: Bool { engine.duration.isFinite && engine.duration > 0 }

    private var activeSkip: (String, VeyraSkipSegment)? {
        let time = engine.currentTime
        if showSkipIntro, let segment = skipSegments.first(where: { $0.type == .intro && $0.contains(time) }) { return ("Intro overslaan", segment) }
        if showSkipRecap, let segment = skipSegments.first(where: { $0.type == .recap && $0.contains(time) }) { return ("Samenvatting overslaan", segment) }
        if showSkipCredits, let segment = skipSegments.first(where: { $0.type == .credits && $0.contains(time) }) { return ("Aftiteling overslaan", segment) }
        if showSkipPreview, let segment = skipSegments.first(where: { $0.type == .preview && $0.contains(time) }) { return ("Preview overslaan", segment) }
        return nil
    }

    /// Per segmenttype in te stellen (spec §69), en alleen voor een segment
    /// dat de minimale confidence-drempel haalt (spec §70) --
    /// `autoSkippedSegmentIDs` voorkomt dat hetzelfde segment bij elke
    /// timer-tick opnieuw geseekt wordt.
    private func handleAutoSkip(at time: Double) {
        let candidates: [(enabled: Bool, type: VeyraSkipSegmentType)] = [
            (autoSkipIntro, .intro),
            (autoSkipRecap, .recap),
            (autoSkipCredits, .credits),
            (autoSkipPreview, .preview),
        ]
        for (enabled, type) in candidates {
            guard enabled,
                let segment = skipSegments.first(where: { $0.type == type && $0.contains(time) }),
                segment.isEligibleForAutoSkip,
                !autoSkippedSegmentIDs.contains(segment.id)
            else { continue }
            let target = segment.end ?? engine.duration
            guard target.isFinite, target > time else { continue }
            autoSkippedSegmentIDs.insert(segment.id)
            Task { await engine.seek(to: target) }
            return
        }
    }

    private var nearEpisodeEnd: Bool {
        canSeek && engine.duration > 30 && engine.currentTime > 10 && engine.currentTime / engine.duration >= 0.95
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if !fullscreen.isPresented || isFullscreenPresentation {
                    AetherPlayerSurface(engine: engine)
                    MacSubtitleOverlay(engine: engine).allowsHitTesting(false)
                } else {
                    Color.black
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black)

            VStack(spacing: 10) {
                if source.kind == .liveTV {
                    LivePlayerEPGTimeline(source: source)
                }
                if canSeek {
                    if source.kind == .liveTV {
                        Text("Streampositie")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    HStack {
                        Text(formatTime(isSeeking ? seekPosition : engine.currentTime))
                        // Fase 7 (cross-platform): macOS heeft geen eigen GeometryReader-track
                        // zoals tvOS/iOS (zie Fase 1-audit), dus de markerlaag wordt hier boven
                        // de bestaande native Slider gelegd met diens eigen breedte.
                        GeometryReader { sliderGeometry in
                            Slider(value: $seekPosition, in: 0...max(engine.duration, 1)) { editing in
                                isSeeking = editing
                                if !editing { Task { await engine.seek(to: seekPosition) } }
                            }
                            .overlay(alignment: .topLeading) {
                                VeyraSkipSegmentMarkerLayer(
                                    segments: skipSegments, duration: engine.duration,
                                    trackWidth: sliderGeometry.size.width, trackHeight: 4,
                                    currentTime: isSeeking ? seekPosition : engine.currentTime
                                ).allowsHitTesting(false)
                            }
                        }
                        .frame(height: 20)
                        Text(formatTime(engine.duration))
                    }
                    .font(.caption.monospacedDigit())
                    .onChange(of: engine.currentTime) { _, time in
                        if !isSeeking { seekPosition = max(0, time) }
                    }
                }

                HStack(spacing: 12) {
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)
                        .frame(maxWidth: 180, alignment: .leading)
                    if source.kind == .liveTV {
                        IPTVLiveProviderStatusBadge(source: source, item: item)
                    }
                    if let connectionStatus {
                        Text(connectionStatus.display)
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(VeyraColors.cyan.opacity(0.22), in: Capsule())
                    }
                    Spacer()
                    Button { Task { await engine.seek(to: max(0, engine.currentTime - 10)) } } label: {
                        Image(systemName: "gobackward.10")
                    }
                    .disabled(!canSeek)
                    Button {
                        if engine.state == .playing { engine.pause() } else { engine.play() }
                    } label: {
                        Image(systemName: engine.state == .playing ? "pause.fill" : "play.fill")
                    }
                    .keyboardShortcut(.space, modifiers: [])
                    Button { Task { await engine.seek(to: min(engine.duration, engine.currentTime + 10)) } } label: {
                        Image(systemName: "goforward.10")
                    }
                    .disabled(!canSeek)

                    Menu {
                        Button("Uit") {
                            SubtitleService.shared.userSelectedTrack()
                            engine.clearSubtitle()
                            engine.clearSecondarySubtitle()
                        }
                        ForEach(engine.subtitleTracks) { track in
                            Button(track.name) {
                                SubtitleService.shared.userSelectedTrack()
                                engine.selectSubtitleTrack(index: track.id)
                            }
                        }
                        Divider()
                        Button("Zoek online via OpenSubtitles…") { showOpenSubtitles = true }
                    } label: { Image(systemName: "captions.bubble") }
                    .help("Ondertitels")

                    Menu {
                        ForEach(engine.audioTracks) { track in
                            Button(track.name) { engine.selectAudioTrack(index: track.id) }
                        }
                    } label: { Image(systemName: "speaker.wave.2") }
                    .help("Audiospoor")

                    Menu {
                        ForEach([Float(0.5), 0.75, 1, 1.25, 1.5, 1.75, 2].filter { $0 <= engine.maxSupportedRate }, id: \.self) { rate in
                            Button(rate == 1 ? "1×" : String(format: "%.2g×", rate)) {
                                playbackRate = rate
                                engine.setRate(rate)
                            }
                        }
                    } label: {
                        Text(playbackRate == 1 ? "1×" : String(format: "%.2g×", playbackRate))
                    }
                    .help("Afspeelsnelheid")

                    MacAirPlayButton()
                        .frame(width: 30, height: 26)
                        .help("AirPlay")

                    if pip.isAvailable {
                        Button(pip.isActive ? "Beeld in beeld stoppen" : "Beeld in beeld", systemImage: "pip") {
                            pip.toggle()
                        }
                    } else {
                        // macOS ondersteunt systeem-PiP niet voor softwarevideo;
                        // een zwevend venster houdt dezelfde Aether-sessie zichtbaar.
                        Button(
                            fullscreen.mode == .floating ? "Beeld in beeld stoppen" : "Beeld in beeld",
                            systemImage: "pip"
                        ) {
                            enterFloatingPlayer()
                        }
                    }

                    Button(
                        isFullscreenPresentation ? "Volledig scherm sluiten" : "Volledig scherm",
                        systemImage: isFullscreenPresentation
                            ? "arrow.down.right.and.arrow.up.left"
                            : "arrow.up.left.and.arrow.down.right"
                    ) {
                        if isFullscreenPresentation {
                            fullscreen.exit()
                        } else {
                            enterFullscreen()
                        }
                    }
                    .help(isFullscreenPresentation ? "Volledig scherm sluiten" : "Volledig scherm")

                    if let nextEpisode {
                        Button(
                            countdownRemaining.map { "Volgende aflevering over \($0)s" } ?? "Volgende aflevering",
                            systemImage: "forward.end.fill"
                        ) {
                            countdownTask?.cancel()
                            onPlayNextEpisode(nextEpisode)
                        }
                        .disabled(resolvingNextEpisode)
                        if countdownRemaining != nil {
                            Button("Aftellen stoppen", systemImage: "xmark") {
                                countdownTask?.cancel()
                                countdownTask = nil
                                countdownRemaining = nil
                                countdownCancelled = true
                            }
                        }
                    }
                }
                .buttonStyle(.borderless)

                if let (label, segment) = activeSkip {
                    Button(label, systemImage: "forward.end") {
                        let target = segment.end ?? engine.duration
                        guard target.isFinite else { return }
                        Task { await engine.seek(to: target) }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(16)
            .background(.black.opacity(0.92))
        }
        .foregroundStyle(.white)
        .onContinuousHover { _ in onUserActivity() }
        .onKeyPress { _ in
            onUserActivity()
            return .ignored
        }
        .sheet(isPresented: $showOpenSubtitles) {
            OpenSubtitlesSearchView(item: item, engine: engine)
                .frame(minWidth: 680, minHeight: 500)
        }
        .task(id: item?.id) {
            autoSkippedSegmentIDs = []
            let identity = VeyraSkipMediaIdentity(
                tmdbID: item?.tmdbID,
                imdbID: item?.imdbID,
                season: item?.type == .series ? item?.seasonNumber : nil,
                episode: item?.type == .series ? item?.episodeNumber : nil,
                duration: canSeek ? engine.duration : nil,
                jellyfinContext: source.jellyfinSkipSegments
            )
            skipSegments = await VeyraSkipSegmentStore.shared.segments(for: identity)
        }
        .onChange(of: engine.currentTime) { _, time in
            guard !fullscreen.isPresented || isFullscreenPresentation else { return }
            handleAutoSkip(at: time)
            startCountdownIfNeeded()
        }
        .veyraEpisodeCompletion(
            engine: engine, item: item, isLive: source.kind == .liveTV || isFullscreenPresentation,
            nextEpisode: nextEpisode, nextEpisodeResolved: nextEpisodeResolved,
            autoAdvanceCancelled: countdownCancelled,
            onNext: { next in countdownTask?.cancel(); onPlayNextEpisode(next) },
            onReturn: { countdownTask?.cancel(); onEpisodeFinished() }
        )
        .onDisappear { countdownTask?.cancel() }
        .onAppear { pip.attach(engine: engine) }
        .task { await loadConnectionStatus() }
        .onChange(of: engine.state) { _, _ in pip.attach(engine: engine) }
        .onChange(of: fullscreen.isPresented) { _, isPresented in
            if isPresented && !isFullscreenPresentation {
                countdownTask?.cancel()
                countdownTask = nil
                countdownRemaining = nil
            }
        }
        .onChange(of: nextEpisode) { _, _ in updateFullscreen() }
        .onChange(of: nextEpisodeResolved) { _, _ in updateFullscreen() }
        .onChange(of: resolvingNextEpisode) { _, _ in updateFullscreen() }
    }

    private func enterFullscreen() {
        if fullscreen.mode == .floating { fullscreen.close() }
        fullscreen.present(title: title, content: fullscreenContent)
    }

    private func enterFloatingPlayer() {
        if fullscreen.mode == .floating {
            fullscreen.close()
            return
        }
        if fullscreen.mode == .fullscreen { fullscreen.close() }
        fullscreen.presentFloating(
            title: title,
            content: MacCompactPlayerSurface(engine: engine, title: title, controller: fullscreen)
        )
    }

    private func updateFullscreen() {
        guard fullscreen.isPresented, !isFullscreenPresentation else { return }
        fullscreen.update(content: fullscreenContent)
    }

    private var fullscreenContent: some View {
        MacPlayerSurface(
            engine: engine,
            title: title,
            item: item,
            source: source,
            nextEpisode: nextEpisode,
            nextEpisodeResolved: nextEpisodeResolved,
            countdownCancelled: $countdownCancelled,
            onEpisodeFinished: onEpisodeFinished,
            resolvingNextEpisode: resolvingNextEpisode,
            onPlayNextEpisode: onPlayNextEpisode,
            pip: pip,
            fullscreen: fullscreen,
            isFullscreenPresentation: true
        )
    }

    private func startCountdownIfNeeded() {
        guard nearEpisodeEnd, let nextEpisode, !resolvingNextEpisode,
              autoPlayNextEpisode, countdownEnabled, !countdownCancelled,
              countdownTask == nil else { return }
        let seconds = (PlaybackCountdownDuration(rawValue: countdownDurationRaw) ?? .ten).seconds
        countdownRemaining = seconds
        countdownTask = Task {
            for remaining in stride(from: seconds - 1, through: 0, by: -1) {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                countdownRemaining = remaining
            }
            guard !Task.isCancelled else { return }
            onPlayNextEpisode(nextEpisode)
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        let value = max(0, Int(seconds))
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}
