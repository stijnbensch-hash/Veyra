import SwiftUI
import AetherEngine

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

                    Button("Sluiten") { dismiss() }
                        .buttonStyle(.borderedProminent)
                }
                .padding(40)

            } else if let playbackEngine = viewModel.playbackEngine {
                iOSPlayerSurface(
                    engine: playbackEngine.engine, title: item?.title, item: item,
                    onClose: { dismiss() },
                    onPlayNextEpisode: { next in nextEpisodeRequest = next }
                )

            } else {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(.white)
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
        .onDisappear {
            viewModel.stopForDisappear()
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

    private var isNearEndOfEpisode: Bool {
        guard engine.duration.isFinite, engine.duration > 0 else { return false }
        return engine.currentTime / engine.duration >= 0.95
    }

    private var showNextEpisodeOverlay: Bool {
        item?.type == .series && nextEpisode != nil && isNearEndOfEpisode
    }

    var body: some View {
        ZStack {
            AetherPlayerSurface(engine: engine)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation { controlsVisible.toggle() }
                    scheduleAutoHide()
                }

            IOSSubtitleOverlay(engine: engine).allowsHitTesting(false)

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
        .onAppear { scheduleAutoHide() }
        .onDisappear { hideTask?.cancel() }
        .task(id: item?.id) {
            nextEpisode = await NextEpisodeResolver.resolve(after: item)
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

            Color.clear.frame(width: 33, height: 33)
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

    // MARK: - Next episode overlay

    private func nextEpisodeOverlayButton(_ next: MediaItem) -> some View {
        Button {
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
