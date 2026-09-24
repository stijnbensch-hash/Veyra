import SwiftUI
import AetherEngine
import UIKit

struct PlayerView: View {
    @Environment(\.dismiss)
    private var dismiss

    let source: PlayableSource
    var item: MediaItem? = nil
    var resumeProgress: Double? = nil

    @Environment(\.scenePhase)
    private var scenePhase

    @StateObject
    private var viewModel: PlaybackViewModel

    @State
    private var nextEpisodeRequest: MediaItem?

    // "Automatisch draaien naar liggend" (Afspelen-instellingen). Uit =
    // speler blijft in staand vergrendeld, ongeacht toestelrotatie.
    @AppStorage(PlaybackSettingsDefaults.autoRotateLandscapeKey)
    private var autoRotateLandscape = true

    // "Voortgangsbalk verbergen" (Laadscherm-instellingen).
    @AppStorage(PlaybackSettingsDefaults.hideProgressBarKey)
    private var hideProgressBar = false

    init(source: PlayableSource, item: MediaItem? = nil, resumeProgress: Double? = nil) {
        self.source = source
        self.item = item
        self.resumeProgress = resumeProgress
        _viewModel = StateObject(
            wrappedValue: PlaybackViewModel(
                source: source,
                item: item,
                resumeProgress: resumeProgress
            )
        )
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let playbackError = viewModel.playbackError {
                VStack(spacing: 16) {
                    Text("Afspelen niet mogelijk")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)

                    Text(playbackError)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)

                    HStack(spacing: 14) {
                        Button("Sluiten") { dismiss() }
                            .buttonStyle(.bordered)

                        Button("Opnieuw proberen") {
                            Task { await viewModel.retry() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(40)

            } else if let playbackEngine = viewModel.playbackEngine {
                iOSPlayerSurface(
                    engine: playbackEngine.engine, title: item?.title, item: item,
                    onClose: { dismiss() },
                    onPlayNextEpisode: { next in
                        // Zie de zelfde fix + toelichting in de tvOS
                        // PlayerView: zonder dit werd de net afgelopen
                        // aflevering niet als "bekeken" geregistreerd bij
                        // Trakt wanneer je op "Volgende" drukt.
                        viewModel.stopForDisappear()
                        nextEpisodeRequest = next
                    }
                )

            } else {
                VStack(spacing: 16) {
                    if !hideProgressBar {
                        ProgressView()
                            .tint(.white)
                    }
                    Text("Veyra Player starten…")
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .task {
            await viewModel.startPlayback()
        }
        .onAppear {
            if autoRotateLandscape {
                OrientationLock.shared.allowAll()
            } else {
                OrientationLock.shared.lockToPortrait()
            }
        }
        .onDisappear {
            viewModel.stopForDisappear()
            OrientationLock.shared.allowAll()
        }
        .onChange(of: scenePhase) { _, phase in
            viewModel.handleScenePhaseChange(phase)
        }
        .navigationDestination(item: $nextEpisodeRequest) { next in
            SourceSelectionView(item: next)
        }
    }
}

private enum IOSPlayerPanel: String, Identifiable {
    case subtitles
    case audio

    var id: String { rawValue }
}

private struct iOSPlayerSurface: View {
    @ObservedObject var engine: AetherEngine
    let title: String?
    var item: MediaItem? = nil
    let onClose: () -> Void
    var onPlayNextEpisode: (MediaItem) -> Void = { _ in }

    @State private var controlsVisible = true
    @State private var isDragging = false
    @State private var dragProgress: Double = 0
    @State private var hideTask: Task<Void, Never>?
    @State private var activePanel: IOSPlayerPanel?
    @State private var nextEpisode: MediaItem?

    // "Hierna"-instellingen (automatisch doorspelen + aftellen). Zelfde
    // sleutels als de tvOS-speler, zie `Shared/Theme/PlaybackSettings.swift`.
    @AppStorage(PlaybackSettingsDefaults.autoPlayNextEpisodeKey)
    private var autoPlayNextEpisodeSetting = true
    @AppStorage(PlaybackSettingsDefaults.autoPlayNextCountdownEnabledKey)
    private var autoPlayNextCountdownEnabled = true
    @AppStorage(PlaybackSettingsDefaults.countdownDurationKey)
    private var countdownDurationRaw = PlaybackCountdownDuration.ten.rawValue

    @State private var countdownRemaining: Int?
    @State private var countdownTask: Task<Void, Never>?
    @State private var countdownCancelled = false

    private var countdownDuration: PlaybackCountdownDuration {
        PlaybackCountdownDuration(rawValue: countdownDurationRaw) ?? .ten
    }

    // Afspeelsnelheid. Bewust niet opgeslagen — per sessie, geen blijvende
    // voorkeur.
    @State private var playbackRate: Float = 1.0

    // Picture-in-Picture en AirPlay. Zie
    // `Veyra-iOS/Playback/AetherPictureInPicture.swift` en `AirPlayButton.swift`.
    @StateObject private var pip = AetherPictureInPictureController()

    // Helderheid/volume via verticale sleepgebaren, zie
    // `Veyra-iOS/Playback/SystemVolumeSlider.swift`.
    @State private var volumeSlider: UISlider?
    @State private var gestureIndicator: (symbol: String, value: Double)?
    @State private var gestureIndicatorTask: Task<Void, Never>?

    // Intro/recap/aftiteling overslaan — zie `Shared/Playback/IntroDBClient.swift`.
    @AppStorage(PlaybackSettingsDefaults.showSkipIntroButtonKey)
    private var showSkipIntroButton = true
    @AppStorage(PlaybackSettingsDefaults.autoSkipIntroKey)
    private var autoSkipIntro = false
    @AppStorage(PlaybackSettingsDefaults.showSkipRecapButtonKey)
    private var showSkipRecapButton = true
    @AppStorage(PlaybackSettingsDefaults.showSkipCreditsButtonKey)
    private var showSkipCreditsButton = true

    @State private var introDBSegments: IntroDBSegments = .empty
    @State private var autoSkippedIntro = false

    private var isNearEndOfEpisode: Bool {
        guard engine.duration.isFinite, engine.duration > 30 else { return false }
        // Vereis ook een minimale verstreken tijd zodat een kort moment met
        // nog onbetrouwbare (bv. verouderde) currentTime/duration-waarden
        // vlak na het laden van een aflevering niet meteen als "einde"
        // wordt gezien — dat veroorzaakte een veel te snelle doorschakeling
        // naar de volgende aflevering.
        guard engine.currentTime > 10 else { return false }
        return engine.currentTime / engine.duration >= 0.95
    }

    // De knop "Volgende aflevering" blijft altijd verschijnen zodra we
    // bijna aan het einde zijn, ongeacht de "Hierna"-instellingen — die
    // bepalen alleen of het automatisch (met aftelling) gebeurt of niet.
    private var showNextEpisodeOverlay: Bool {
        item?.type == .series && nextEpisode != nil
            && isNearEndOfEpisode && !countdownCancelled
    }

    private enum SkipSegmentKind {
        case intro, recap, credits

        var label: String {
            switch self {
            case .intro: return "Intro overslaan"
            case .recap: return "Samenvatting overslaan"
            case .credits: return "Aftiteling overslaan"
            }
        }
    }

    private var activeSkipSegment: (kind: SkipSegmentKind, segment: IntroDBSegment)? {
        guard !showNextEpisodeOverlay else { return nil }

        if showSkipIntroButton, let intro = introDBSegments.intro, intro.contains(engine.currentTime) {
            return (.intro, intro)
        }
        if showSkipRecapButton, let recap = introDBSegments.recap, recap.contains(engine.currentTime) {
            return (.recap, recap)
        }
        if showSkipCreditsButton, let credits = introDBSegments.credits,
            credits.contains(engine.currentTime)
        {
            return (.credits, credits)
        }
        return nil
    }

    private func skipSegment(_ segment: IntroDBSegment) {
        let target = segment.end ?? engine.duration
        guard target.isFinite, target > engine.currentTime else { return }
        Task { await engine.seek(to: target) }
    }

    private func handleAutoSkip(at time: Double) {
        guard autoSkipIntro, !autoSkippedIntro, let intro = introDBSegments.intro,
            let end = intro.end, intro.contains(time)
        else { return }
        autoSkippedIntro = true
        Task { await engine.seek(to: end) }
    }

    var body: some View {
        ZStack {
            AetherPlayerSurface(engine: engine)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation { controlsVisible.toggle() }
                    scheduleAutoHide()
                }
                .gesture(brightnessVolumeGesture)

            IOSSubtitleOverlay(engine: engine).allowsHitTesting(false)

            SystemVolumeSlider(slider: $volumeSlider).frame(width: 0, height: 0).opacity(0)

            if let indicator = gestureIndicator {
                gestureIndicatorView(indicator.symbol, value: indicator.value)
                    .transition(.opacity)
            }

            if let active = activeSkipSegment {
                VStack {
                    Spacer()
                    HStack {
                        skipSegmentButton(active.kind, active.segment)
                        Spacer()
                    }
                }
                .padding(.leading, 16)
                .padding(.bottom, controlsVisible ? 148 : 28)
                .transition(.opacity)
            }

            if showNextEpisodeOverlay, let nextEpisode {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        nextEpisodeOverlayButton(nextEpisode)
                    }
                }
                .padding(.trailing, 16)
                .padding(.bottom, controlsVisible ? 148 : 28)
                .transition(.opacity)
                .onAppear { startCountdownIfNeeded(for: nextEpisode) }
            }

            if controlsVisible {
                VStack {
                    topBar
                    Spacer()
                    bottomControls
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            scheduleAutoHide()
            pip.attach(engine: engine)
        }
        .onDisappear { hideTask?.cancel(); countdownTask?.cancel() }
        .task(id: item?.id) {
            countdownTask?.cancel()
            countdownTask = nil
            countdownRemaining = nil
            countdownCancelled = false
            autoSkippedIntro = false
            introDBSegments = .empty
            nextEpisode = await NextEpisodeResolver.resolve(after: item)
            introDBSegments = await IntroDBClient.shared.segments(
                tmdbID: item?.tmdbID,
                season: item?.type == .series ? item?.seasonNumber : nil,
                episode: item?.type == .series ? item?.episodeNumber : nil,
                durationSeconds: engine.duration > 0 ? engine.duration : nil
            )
        }
        .onChange(of: engine.currentTime) { _, time in
            handleAutoSkip(at: time)
        }
        .sheet(item: $activePanel) { panel in
            Group {
                switch panel {
                case .subtitles:
                    IOSSubtitleTrackSheet(engine: engine, item: item)
                case .audio:
                    IOSAudioTrackSheet(engine: engine)
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(11)
                    .background(.black.opacity(0.4), in: Circle())
            }

            Spacer()

            if let title, !title.isEmpty {
                VStack(spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if let episodeLabel {
                        Text(episodeLabel)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(VeyraColors.cyan)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            HStack(spacing: 10) {
                if pip.isAvailable {
                    Button {
                        pip.toggle()
                    } label: {
                        Image(systemName: pip.isActive ? "pip.exit" : "pip.enter")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(11)
                            .background(.black.opacity(0.4), in: Circle())
                    }
                }

                AirPlayButton()
                    .frame(width: 33, height: 33)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Bottom controls

    private var bottomControls: some View {
        VStack(spacing: 8) {
            HStack {
                Text(time(displayedTime))
                    .font(.system(size: 17, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.9))

                Spacer()

                Text(time(engine.duration))
                    .font(.system(size: 17, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.9))
            }

            IOSPlaybackTimeline(engine: engine, isDragging: $isDragging, dragProgress: $dragProgress)

            HStack(spacing: 20) {
                Spacer(minLength: 0)

                Button {
                    activePanel = .subtitles
                } label: {
                    Image(systemName: engine.isSubtitleActive ? "captions.bubble.fill" : "captions.bubble")
                        .font(.system(size: 18))
                        .foregroundStyle(engine.isSubtitleActive ? VeyraColors.cyan : .white)
                        .frame(width: 40, height: 40)
                }

                Button {
                    seek(by: -10)
                    scheduleAutoHide()
                } label: {
                    Image(systemName: "gobackward.10")
                        .font(.system(size: 19))
                        .frame(width: 46, height: 46)
                }
                .disabled(!canSeek)

                Button {
                    togglePlayback()
                    scheduleAutoHide()
                } label: {
                    Image(systemName: engine.state == .playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 22))
                        .frame(width: 54, height: 54)
                        .background(VeyraColors.red.opacity(0.22), in: Circle())
                }

                Button {
                    seek(by: 10)
                    scheduleAutoHide()
                } label: {
                    Image(systemName: "goforward.10")
                        .font(.system(size: 19))
                        .frame(width: 46, height: 46)
                }
                .disabled(!canSeek)

                Button {
                    activePanel = .audio
                } label: {
                    Image(systemName: "waveform")
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                }

                speedMenu

                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .veyraGlass(radius: VeyraRadius.card, backgroundOpacity: 0.4)
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }

    // MARK: - Speed

    private var availablePlaybackRates: [Float] {
        [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0].filter { $0 <= engine.maxSupportedRate }
    }

    private func speedLabel(_ rate: Float) -> String {
        rate == 1.0 ? "1x" : String(format: "%.2gx", rate)
    }

    private var speedMenu: some View {
        Menu {
            ForEach(availablePlaybackRates, id: \.self) { rate in
                Button {
                    playbackRate = rate
                    engine.setRate(rate)
                } label: {
                    if rate == playbackRate {
                        Label(speedLabel(rate), systemImage: "checkmark")
                    } else {
                        Text(speedLabel(rate))
                    }
                }
            }
        } label: {
            Text(speedLabel(playbackRate))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
        }
    }

    // MARK: - Skip segment overlay

    private func skipSegmentButton(_ kind: SkipSegmentKind, _ segment: IntroDBSegment) -> some View {
        Button {
            skipSegment(segment)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "forward.end.fill")
                Text(kind.label)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.black.opacity(0.55), in: Capsule())
        }
    }

    // MARK: - Brightness/volume gesture

    private var brightnessVolumeGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                let isLeftSide = value.startLocation.x < UIScreen.main.bounds.width / 2
                let delta = Double(-value.translation.height / 200)

                if isLeftSide {
                    let newValue = min(1, max(0, UIScreen.main.brightness + delta / 30))
                    UIScreen.main.brightness = newValue
                    showGestureIndicator(symbol: "sun.max.fill", value: newValue)
                } else if let volumeSlider {
                    let newValue = min(1, max(0, Double(volumeSlider.value) + delta / 30))
                    volumeSlider.value = Float(newValue)
                    showGestureIndicator(symbol: "speaker.wave.2.fill", value: newValue)
                }
            }
    }

    private func showGestureIndicator(symbol: String, value: Double) {
        gestureIndicator = (symbol, value)
        gestureIndicatorTask?.cancel()
        gestureIndicatorTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            withAnimation { gestureIndicator = nil }
        }
    }

    private func gestureIndicatorView(_ symbol: String, value: Double) -> some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 22))
            ProgressView(value: value)
                .frame(width: 90)
        }
        .foregroundStyle(.white)
        .padding(18)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Next episode overlay

    @ViewBuilder
    private func nextEpisodeOverlayButton(_ next: MediaItem) -> some View {
        if autoPlayNextEpisodeSetting, autoPlayNextCountdownEnabled, let countdownRemaining {
            HStack(spacing: 10) {
                Button {
                    countdownTask?.cancel()
                    countdownTask = nil
                    countdownCancelled = true
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.black.opacity(0.55), in: Circle())
                }

                Button {
                    countdownTask?.cancel()
                    onPlayNextEpisode(next)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "forward.end.fill")
                        Text("Volgende aflevering over \(countdownRemaining)s")
                            .font(.system(size: 15, weight: .semibold)).monospacedDigit()
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(.black.opacity(0.55), in: Capsule())
                }
            }
        } else {
            Button {
                countdownTask?.cancel()
                onPlayNextEpisode(next)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "forward.end.fill")
                    Text("Volgende aflevering")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(.black.opacity(0.55), in: Capsule())
            }
        }
    }

    private func startCountdownIfNeeded(for next: MediaItem) {
        guard autoPlayNextEpisodeSetting, autoPlayNextCountdownEnabled, countdownTask == nil,
              !countdownCancelled
        else { return }
        countdownRemaining = countdownDuration.seconds
        countdownTask = Task {
            while let remaining = countdownRemaining, remaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                countdownRemaining = remaining - 1
            }
            guard !Task.isCancelled else { return }
            onPlayNextEpisode(next)
        }
    }

    // MARK: - Helpers

    private var episodeLabel: String? {
        guard item?.type == .series,
              let season = item?.seasonNumber,
              let episode = item?.episodeNumber
        else { return nil }

        return "S\(season) · A\(episode)"
    }

    private var canSeek: Bool { engine.duration.isFinite && engine.duration > 0 }

    private var displayedTime: Double {
        if isDragging, canSeek {
            return dragProgress * engine.duration
        }
        return engine.currentTime
    }

    private func togglePlayback() {
        if engine.state == .playing {
            engine.pause()
        } else {
            engine.play()
        }
    }

    private func seek(by offset: Double) {
        guard canSeek else { return }
        let target = min(engine.duration, max(0, engine.currentTime + offset))
        Task { await engine.seek(to: target) }
    }

    private func scheduleAutoHide() {
        hideTask?.cancel()
        guard controlsVisible else { return }

        hideTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation { controlsVisible = false }
        }
    }

    private func time(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0, seconds < Double(Int.max) else { return "—" }
        let total = Int(seconds)
        return String(format: "%d:%02d:%02d", total / 3600, total / 60 % 60, total % 60)
    }
}

// MARK: - Timeline

private struct IOSPlaybackTimeline: View {
    @ObservedObject var engine: AetherEngine
    @Binding var isDragging: Bool
    @Binding var dragProgress: Double

    var body: some View {
        GeometryReader { geometry in
            let duration = engine.duration.isFinite ? max(engine.duration, 0) : 0
            let liveTime = engine.currentTime.isFinite ? max(engine.currentTime, 0) : 0
            let liveProgress = duration > 0 ? min(liveTime / duration, 1) : 0
            let progress = isDragging ? dragProgress : liveProgress

            let bufferedRaw = engine.bufferedPosition
            let safeBuffered = bufferedRaw.isFinite ? max(bufferedRaw, 0) : 0
            let bufferedProgress = duration > 0 ? min(1, safeBuffered / duration) : 0

            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.24))

                Capsule().fill(Color(red: 0.62, green: 0.93, blue: 1.0).opacity(0.5))
                    .frame(width: geometry.size.width * CGFloat(bufferedProgress))

                Capsule().fill(VeyraColors.red)
                    .frame(width: geometry.size.width * CGFloat(progress))

                Circle().fill(.white).frame(width: 14, height: 14)
                    .shadow(color: .black.opacity(0.4), radius: 3)
                    .offset(
                        x: max(
                            0,
                            min(geometry.size.width - 14, geometry.size.width * CGFloat(progress) - 7)
                        )
                    )
            }
            .frame(height: 14)
            .contentShape(Rectangle().inset(by: -10))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard duration > 0 else { return }
                        isDragging = true
                        dragProgress = min(max(0, value.location.x / geometry.size.width), 1)
                    }
                    .onEnded { value in
                        guard duration > 0 else { isDragging = false; return }
                        let ratio = min(max(0, value.location.x / geometry.size.width), 1)
                        let target = ratio * duration
                        Task {
                            await engine.seek(to: target)
                            isDragging = false
                        }
                    }
            )
        }
        .frame(height: 20)
    }
}

// MARK: - Subtitle overlay

private struct IOSSubtitleOverlay: View {
    @ObservedObject var engine: AetherEngine

    @AppStorage("veyra.subtitle.size") private var subtitleSizeRaw = "normal"
    @AppStorage("veyra.subtitle.position") private var subtitlePositionRaw = "low"
    @AppStorage("veyra.subtitle.background") private var subtitleBackgroundRaw = "subtle"
    @AppStorage("veyra.subtitle.shadow") private var subtitleShadow = true
    @AppStorage("veyra.subtitle.offset") private var subtitleOffset: Double = 0

    private var sizeMultiplier: CGFloat {
        switch subtitleSizeRaw {
        case "small": return 0.82
        case "large": return 1.22
        default: return 1.0
        }
    }

    private func bottomPadding(for height: CGFloat) -> CGFloat {
        switch subtitlePositionRaw {
        case "standard": return max(70, height * 0.075)
        case "high": return max(110, height * 0.13)
        default: return max(42, height * 0.045)
        }
    }

    private var backgroundOpacity: Double {
        switch subtitleBackgroundRaw {
        case "strong": return 0.70
        case "none": return 0
        default: return 0.42
        }
    }

    private var usesNativeRendering: Bool {
        engine.subtitleTracks.first { $0.id == engine.activeSubtitleTrackIndex }?
            .isNativelyRenderedSubtitle == true
    }

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.periodic(from: .now, by: 0.1)) { _ in
                let adjustedSourceTime = engine.sourceTime - subtitleOffset

                let cues =
                    engine.isSubtitleActive && !usesNativeRendering
                    ? engine.subtitleCues.filter {
                        $0.startTime <= adjustedSourceTime && adjustedSourceTime < $0.endTime
                    } : []

                ZStack {
                    ForEach(cues) { cue in
                        if case .image(let bitmap) = cue.body {
                            bitmapView(bitmap, in: geometry.size)
                        }
                    }

                    VStack {
                        Spacer(minLength: 0)

                        VStack(spacing: 6) {
                            ForEach(cues) { cue in
                                if let text = cue.text, !text.isEmpty {
                                    subtitleText(text, geometry: geometry)
                                }
                            }
                        }
                        .frame(maxWidth: geometry.size.width * 0.9)
                        .padding(.bottom, bottomPadding(for: geometry.size.height))
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .accessibilityHidden(true)
    }

    private func subtitleText(_ text: String, geometry: GeometryProxy) -> some View {
        let baseSize = max(16, geometry.size.height * 0.03)
        let fontSize = baseSize * sizeMultiplier

        return Text(text)
            .font(.system(size: fontSize, weight: .semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .shadow(
                color: subtitleShadow ? .black.opacity(0.95) : .clear,
                radius: subtitleShadow ? 4 : 0, x: 1, y: 2
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.black.opacity(backgroundOpacity))
            )
            .fixedSize(horizontal: false, vertical: true)
    }

    private func bitmapView(_ bitmap: SubtitleImage, in size: CGSize) -> some View {
        let source =
            engine.sourceVideoWidth > 0 && engine.sourceVideoHeight > 0
            ? CGSize(width: CGFloat(engine.sourceVideoWidth), height: CGFloat(engine.sourceVideoHeight))
            : size

        let pixelAspect = CGFloat(engine.sourceVideoPixelAspectRatio)
        let safePixelAspect = pixelAspect > 0 ? pixelAspect : 1

        let videoScale = min(
            size.width / (source.width * safePixelAspect), size.height / source.height)

        let width = source.width * safePixelAspect * videoScale

        let canvas =
            bitmap.canvasSize.width > 0 && bitmap.canvasSize.height > 0 ? bitmap.canvasSize : source

        let height = canvas.height * width / (canvas.width * safePixelAspect)

        return Image(decorative: bitmap.cgImage, scale: 1).resizable()
            .frame(width: bitmap.position.width * width, height: bitmap.position.height * height)
            .position(
                x: (size.width - width) / 2 + bitmap.position.midX * width,
                y: (size.height - height) / 2 + bitmap.position.midY * height
            )
    }
}

// MARK: - Subtitle track sheet

private struct IOSSubtitleTrackSheet: View {
    @ObservedObject var engine: AetherEngine
    var item: MediaItem?

    @Environment(\.dismiss) private var dismiss
    @State private var showOpenSubtitlesSearch = false

    @AppStorage(SubtitleAppearanceDefaults.sizeKey)
    private var subtitleSizeRaw = VeyraSubtitleSize.normal.rawValue
    @AppStorage(SubtitleAppearanceDefaults.positionKey)
    private var subtitlePositionRaw = VeyraSubtitlePosition.low.rawValue
    @AppStorage(SubtitleAppearanceDefaults.backgroundKey)
    private var subtitleBackgroundRaw = VeyraSubtitleBackground.subtle.rawValue
    @AppStorage(SubtitleAppearanceDefaults.shadowKey)
    private var subtitleShadow = true
    @AppStorage(SubtitleAppearanceDefaults.offsetKey)
    private var subtitleOffset: Double = 0

    private var subtitleSize: VeyraSubtitleSize {
        VeyraSubtitleSize(rawValue: subtitleSizeRaw) ?? .normal
    }
    private var subtitlePosition: VeyraSubtitlePosition {
        VeyraSubtitlePosition(rawValue: subtitlePositionRaw) ?? .low
    }
    private var subtitleBackground: VeyraSubtitleBackground {
        VeyraSubtitleBackground(rawValue: subtitleBackgroundRaw) ?? .subtle
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VeyraColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        trackRow(
                            title: "Uit", subtitle: "Geen ondertitels",
                            systemImage: "captions.bubble.fill",
                            selected: !engine.isSubtitleActive
                        ) {
                            SubtitleService.shared.userSelectedTrack()
                            engine.clearSubtitle()
                            engine.clearSecondarySubtitle()
                            dismiss()
                        }

                        ForEach(engine.subtitleTracks) { track in
                            trackRow(
                                title: title(track), subtitle: details(track),
                                systemImage: "captions.bubble",
                                selected: engine.activeSubtitleTrackIndex == track.id
                            ) {
                                SubtitleService.shared.userSelectedTrack()
                                engine.selectSubtitleTrack(index: track.id)
                                dismiss()
                            }
                        }

                        if engine.subtitleTracks.isEmpty && !engine.isLoadingSubtitles {
                            Text("Deze stream biedt momenteel geen selecteerbare ondertitels aan.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.6))
                                .padding(.top, 12)
                        }

                        if engine.isLoadingSubtitles {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Ondertitels laden…").foregroundStyle(.white.opacity(0.6))
                            }
                            .padding(.top, 12)
                        }

                        Button {
                            showOpenSubtitlesSearch = true
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "globe")
                                    .font(.system(size: 18))
                                    .foregroundStyle(VeyraColors.cyan)
                                    .frame(width: 28)

                                Text("Zoek online via OpenSubtitles")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.white)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .veyraGlass(radius: 14, backgroundOpacity: 0.6)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 12)

                        sectionHeader("WEERGAVE")

                        appearanceRow(
                            title: "Tekstgrootte", value: subtitleSize.title,
                            systemImage: "textformat.size"
                        ) { cycleSubtitleSize() }

                        appearanceRow(
                            title: "Achtergrond", value: subtitleBackground.title,
                            systemImage: "rectangle.fill"
                        ) { cycleBackground() }

                        appearanceRow(
                            title: "Plaatsing", value: subtitlePosition.title,
                            systemImage: "rectangle.bottomthird.inset.filled"
                        ) { cyclePosition() }

                        appearanceRow(
                            title: "Schaduw", value: subtitleShadow ? "Aan" : "Uit",
                            systemImage: "shadow"
                        ) { subtitleShadow.toggle() }

                        sectionHeader("SYNCHRONISATIE")

                        Text(currentOffsetDescription)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.bottom, 4)

                        actionRow(title: "10 sec vroeger", systemImage: "gobackward.10") {
                            adjustOffset(by: -10)
                        }
                        actionRow(title: "0,1 sec vroeger", systemImage: "minus") {
                            adjustOffset(by: -0.1)
                        }
                        actionRow(title: "0,1 sec later", systemImage: "plus") {
                            adjustOffset(by: 0.1)
                        }
                        actionRow(title: "10 sec later", systemImage: "goforward.10") {
                            adjustOffset(by: 10)
                        }
                        if subtitleOffset != 0 {
                            actionRow(title: "Terugzetten naar 0,0s", systemImage: "arrow.counterclockwise") {
                                subtitleOffset = 0
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Ondertitels")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Sluiten") { dismiss() }
                }
            }
            .sheet(isPresented: $showOpenSubtitlesSearch) {
                OpenSubtitlesSearchView(item: item, engine: engine)
            }
        }
    }

    private func trackRow(
        title: String, subtitle: String, systemImage: String, selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 18))
                    .foregroundStyle(VeyraColors.cyan)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)

                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                Spacer()

                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(VeyraColors.cyan)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .veyraGlass(radius: 14, backgroundOpacity: selected ? 1.0 : 0.6)
        }
        .buttonStyle(.plain)
    }

    private func title(_ track: TrackInfo) -> String {
        if let language = track.language, !language.isEmpty, language != "und" {
            return Locale(identifier: "nl").localizedString(forLanguageCode: language) ?? language
        }
        return track.name.isEmpty ? "Ondertitelspoor \(track.id)" : track.name
    }

    private func details(_ track: TrackInfo) -> String {
        var parts = [track.name, track.codec.uppercased()].filter { !$0.isEmpty }
        if track.isForced { parts.append("Alleen anderstalige dialoog") }
        if track.isHearingImpaired { parts.append("SDH") }
        return parts.joined(separator: " · ")
    }

    // MARK: - Weergave & synchronisatie

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .tracking(2)
            .foregroundStyle(.white.opacity(0.5))
            .padding(.top, 22)
    }

    private func appearanceRow(
        title: String, value: String, systemImage: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 18))
                    .foregroundStyle(VeyraColors.cyan)
                    .frame(width: 28)

                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)

                Spacer()

                Text(value)
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.6))

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .veyraGlass(radius: 14, backgroundOpacity: 0.6)
        }
        .buttonStyle(.plain)
    }

    private func actionRow(
        title: String, systemImage: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 18))
                    .foregroundStyle(VeyraColors.cyan)
                    .frame(width: 28)

                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .veyraGlass(radius: 14, backgroundOpacity: 0.6)
        }
        .buttonStyle(.plain)
    }

    private var currentOffsetDescription: String {
        if subtitleOffset == 0 {
            return "Ondertitels lopen gelijk met het geluid."
        }
        let sign = subtitleOffset > 0 ? "+" : ""
        return "Huidige verschuiving: \(sign)\(String(format: "%.1f", subtitleOffset))s"
    }

    private func cycleSubtitleSize() {
        switch subtitleSize {
        case .small: subtitleSizeRaw = VeyraSubtitleSize.normal.rawValue
        case .normal: subtitleSizeRaw = VeyraSubtitleSize.large.rawValue
        case .large: subtitleSizeRaw = VeyraSubtitleSize.small.rawValue
        }
    }

    private func cyclePosition() {
        switch subtitlePosition {
        case .low: subtitlePositionRaw = VeyraSubtitlePosition.standard.rawValue
        case .standard: subtitlePositionRaw = VeyraSubtitlePosition.high.rawValue
        case .high: subtitlePositionRaw = VeyraSubtitlePosition.low.rawValue
        }
    }

    private func cycleBackground() {
        switch subtitleBackground {
        case .none: subtitleBackgroundRaw = VeyraSubtitleBackground.subtle.rawValue
        case .subtle: subtitleBackgroundRaw = VeyraSubtitleBackground.strong.rawValue
        case .strong: subtitleBackgroundRaw = VeyraSubtitleBackground.none.rawValue
        }
    }

    private func adjustOffset(by delta: Double) {
        let clamped = min(60, max(-60, subtitleOffset + delta))
        subtitleOffset = (clamped * 10).rounded() / 10
    }
}

// MARK: - Audio track sheet

private struct IOSAudioTrackSheet: View {
    @ObservedObject var engine: AetherEngine

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                VeyraColors.background.ignoresSafeArea()

                if engine.audioTracks.isEmpty {
                    Text("Geen audiotracks beschikbaar voor deze stream.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(24)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(engine.audioTracks) { track in
                                Button {
                                    engine.selectAudioTrack(index: track.id)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 14) {
                                        Image(
                                            systemName: engine.activeAudioTrackIndex == track.id
                                                ? "checkmark.circle.fill" : "circle"
                                        )
                                        .foregroundStyle(VeyraColors.cyan)

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(track.name.isEmpty ? "Audiotrack \(track.id + 1)" : track.name)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundStyle(.white)

                                            Text(audioDescription(track))
                                                .font(.footnote)
                                                .foregroundStyle(.white.opacity(0.6))
                                        }

                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .veyraGlass(
                                        radius: 14,
                                        backgroundOpacity: engine.activeAudioTrackIndex == track.id ? 1.0 : 0.6
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Audio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Sluiten") { dismiss() }
                }
            }
        }
    }

    private func audioDescription(_ track: TrackInfo) -> String {
        var parts: [String] = []

        if let language = track.language {
            parts.append(
                Locale(identifier: "nl_NL").localizedString(forLanguageCode: language) ?? language)
        }

        if !track.codec.isEmpty { parts.append(track.codec.uppercased()) }
        if track.channels > 0 { parts.append("\(track.channels) kanalen") }

        return parts.joined(separator: " · ")
    }
}
