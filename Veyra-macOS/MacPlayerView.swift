import SwiftUI
import AetherEngine

struct PlayerView: View {
    let source: PlayableSource
    var item: MediaItem? = nil
    var resumeProgress: Double? = nil

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: PlaybackViewModel
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
                    .overlay(alignment: .bottom) {
                        Button("Opnieuw proberen") { Task { await viewModel.retry() } }
                            .padding()
                    }
            } else if let playbackEngine = viewModel.playbackEngine {
                MacPlayerSurface(
                    engine: playbackEngine.engine,
                    title: item?.title ?? source.name,
                    item: item,
                    nextEpisode: nextEpisode,
                    resolvingNextEpisode: resolvingNextEpisode,
                    onPlayNextEpisode: playNextEpisode
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
        .task { await viewModel.startPlayback() }
        .task(id: item?.id) { nextEpisode = await NextEpisodeResolver.resolve(after: item) }
        .onDisappear { viewModel.stopForDisappear() }
        .navigationDestination(item: $nextRequest) { request in
            if let source = request.source {
                PlayerView(source: source, item: request.item)
            } else {
                SourceSelectionView(item: request.item)
            }
        }
        .frame(minWidth: 680, minHeight: 440)
    }

    private func playNextEpisode(_ next: MediaItem) {
        guard !resolvingNextEpisode else { return }
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

private struct MacPlayerSurface: View {
    @ObservedObject var engine: AetherEngine
    let title: String
    let item: MediaItem?
    let nextEpisode: MediaItem?
    let resolvingNextEpisode: Bool
    let onPlayNextEpisode: (MediaItem) -> Void

    @State private var seekPosition: Double = 0
    @State private var isSeeking = false
    @State private var showOpenSubtitles = false
    @State private var skipSegments: IntroDBSegments = .empty
    @State private var autoSkippedIntro = false
    @State private var countdownRemaining: Int?
    @State private var countdownTask: Task<Void, Never>?
    @State private var countdownCancelled = false
    @State private var playbackRate: Float = 1
    @StateObject private var pip = MacPictureInPictureController()

    @AppStorage(PlaybackSettingsDefaults.showSkipIntroButtonKey) private var showSkipIntro = true
    @AppStorage(PlaybackSettingsDefaults.autoSkipIntroKey) private var autoSkipIntro = false
    @AppStorage(PlaybackSettingsDefaults.showSkipRecapButtonKey) private var showSkipRecap = true
    @AppStorage(PlaybackSettingsDefaults.showSkipCreditsButtonKey) private var showSkipCredits = true
    @AppStorage(PlaybackSettingsDefaults.autoPlayNextEpisodeKey) private var autoPlayNextEpisode = true
    @AppStorage(PlaybackSettingsDefaults.autoPlayNextCountdownEnabledKey) private var countdownEnabled = true
    @AppStorage(PlaybackSettingsDefaults.countdownDurationKey)
    private var countdownDurationRaw = PlaybackCountdownDuration.ten.rawValue

    private var canSeek: Bool { engine.duration.isFinite && engine.duration > 0 }

    private var activeSkip: (String, IntroDBSegment)? {
        let time = engine.currentTime
        if showSkipIntro, let segment = skipSegments.intro, segment.contains(time) { return ("Intro overslaan", segment) }
        if showSkipRecap, let segment = skipSegments.recap, segment.contains(time) { return ("Samenvatting overslaan", segment) }
        if showSkipCredits, let segment = skipSegments.credits, segment.contains(time) { return ("Aftiteling overslaan", segment) }
        return nil
    }

    private var nearEpisodeEnd: Bool {
        canSeek && engine.duration > 30 && engine.currentTime > 10 && engine.currentTime / engine.duration >= 0.95
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                AetherPlayerSurface(engine: engine)
                MacSubtitleOverlay(engine: engine).allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black)

            VStack(spacing: 10) {
                if canSeek {
                    HStack {
                        Text(formatTime(isSeeking ? seekPosition : engine.currentTime))
                        Slider(value: $seekPosition, in: 0...max(engine.duration, 1)) { editing in
                            isSeeking = editing
                            if !editing { Task { await engine.seek(to: seekPosition) } }
                        }
                        Text(formatTime(engine.duration))
                    }
                    .font(.caption.monospacedDigit())
                    .onChange(of: engine.currentTime) { _, time in
                        if !isSeeking { seekPosition = max(0, time) }
                    }
                }

                HStack(spacing: 18) {
                    Text(title).font(.headline).lineLimit(1)
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
                        Button("Beeld in beeld", systemImage: "pip") { pip.toggle() }
                    }

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
        .sheet(isPresented: $showOpenSubtitles) {
            OpenSubtitlesSearchView(item: item, engine: engine)
                .frame(minWidth: 680, minHeight: 500)
        }
        .task(id: item?.id) {
            skipSegments = await IntroDBClient.shared.segments(
                tmdbID: item?.tmdbID,
                season: item?.type == .series ? item?.seasonNumber : nil,
                episode: item?.type == .series ? item?.episodeNumber : nil,
                durationSeconds: canSeek ? engine.duration : nil
            )
        }
        .onChange(of: engine.currentTime) { _, time in
            if autoSkipIntro, !autoSkippedIntro,
               let intro = skipSegments.intro, let end = intro.end, intro.contains(time) {
                autoSkippedIntro = true
                Task { await engine.seek(to: end) }
            }
            startCountdownIfNeeded()
        }
        .onDisappear { countdownTask?.cancel() }
        .onAppear { pip.attach(engine: engine) }
        .onChange(of: engine.state) { _, _ in pip.attach(engine: engine) }
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
