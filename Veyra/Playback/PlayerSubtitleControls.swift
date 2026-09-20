import AetherEngine
import SwiftUI

// MARK: - Subtitle preferences

private enum VeyraSubtitlePosition: String, CaseIterable {
    case low
    case standard
    case high

    var title: String {
        switch self {
        case .low: return "Laag"

        case .standard: return "Standaard"

        case .high: return "Hoog"
        }
    }

    func bottomPadding(for height: CGFloat) -> CGFloat {
        switch self {
        case .low: return max(42, height * 0.045)

        case .standard: return max(70, height * 0.075)

        case .high: return max(110, height * 0.13)
        }
    }
}

private enum VeyraSubtitleSize: String, CaseIterable {
    case small
    case normal
    case large

    var title: String {
        switch self {
        case .small: return "Klein"

        case .normal: return "Normaal"

        case .large: return "Groot"
        }
    }

    var multiplier: CGFloat {
        switch self {
        case .small: return 0.82

        case .normal: return 1.0

        case .large: return 1.22
        }
    }
}

private enum VeyraSubtitleBackground: String, CaseIterable {
    case none
    case subtle
    case strong

    var title: String {
        switch self {
        case .none: return "Geen"

        case .subtle: return "Subtiel"

        case .strong: return "Donker"
        }
    }

    var opacity: Double {
        switch self {
        case .none: return 0

        case .subtle: return 0.42

        case .strong: return 0.70
        }
    }
}

// MARK: - Player controls

struct PlayerSubtitleControls: View {
    @ObservedObject var engine: AetherEngine

    var title: String? = nil
    var item: MediaItem? = nil

    var onRequestExit: () -> Void = {}
    var onPlayNextEpisode: (MediaItem) -> Void = { _ in }

    @Environment(\.scenePhase) private var scenePhase

    @State private var presentation = VeyraPlayerPresentation()
    @State private var nextEpisode: MediaItem?

    private var controlsVisible: Bool { presentation.controlsVisible }
    private var showingSubtitles: Bool { presentation.panel == .subtitles }
    private var showingAudio: Bool { presentation.panel == .audio }

    @State private var interaction = 0

    @StateObject private var seekController = VeyraPlayerSeekController()

    @FocusState private var focused: Control?

    @FocusState private var audioFocused: AudioFocus?

    private typealias Control = VeyraPlayerControl

    private enum AudioFocus: Hashable {
        case close
        case track(Int)
    }

    private var panelVisible: Bool { showingSubtitles || showingAudio }

    private var isNearEndOfEpisode: Bool {
        guard engine.duration.isFinite, engine.duration > 0 else { return false }
        return engine.currentTime / engine.duration >= 0.95
    }

    private var showNextEpisodeOverlay: Bool {
        item?.type == .series && nextEpisode != nil && !panelVisible && isNearEndOfEpisode
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear.contentShape(Rectangle()).focusable(!controlsVisible && !panelVisible)
                .focused($focused, equals: .surface).focusEffectDisabled().onMoveCommand { _ in
                    guard !panelVisible else { return }

                    revealControls(focus: .play)
                }.onTapGesture { revealControls(focus: .play) }

            Color.black.opacity(controlsVisible || panelVisible ? 0.16 : 0).allowsHitTesting(false)

            PlayerSubtitleOverlay(engine: engine).allowsHitTesting(false)

            if showNextEpisodeOverlay, let nextEpisode {
                nextEpisodeOverlayButton(nextEpisode)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 72)
                    .padding(.bottom, controlsVisible ? 190 : 48)
            }

            if controlsVisible && !panelVisible { playbackControls }
        }.onChange(of: isNearEndOfEpisode) { _, isNear in
            guard isNear, showNextEpisodeOverlay else { return }
            focused = .nextEpisode
        }.onAppear {
            presentation.revealControls()
            restoreControlFocus(.play)
        }.onChange(of: focused) { _, _ in interaction += 1 }.onChange(of: audioFocused) { _, _ in
            interaction += 1
        }.onDisappear { seekController.cancel() }.onChange(of: scenePhase) { _, phase in
            if phase != .active { seekController.cancel() }
        }.onChange(of: canSeek) { _, available in
            if !available {
                seekController.cancel()
                if focused == .timeline || focused == .backward || focused == .forward {
                    focused = .play
                }
            }
        }.task(id: interaction) {
            guard !panelVisible else { return }

            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(6)) } catch { return }
                guard !panelVisible else { return }
                // Do not remove the timeline while a slow seek is pending.
                guard seekController.previewTime == nil else { continue }
                presentation.hideControls()
                focused = .surface
                return
            }
        }.overlay(alignment: .trailing) {
            if showingSubtitles {
                SubtitleSettingsPanel(engine: engine, item: item) { closeSubtitles() }.frame(
                    width: 820
                ).padding(32).focusSection()

            } else if showingAudio {
                audioPanel.frame(width: 680).padding(32).focusSection()
            }
        }
        // One handler outside the overlay owns Back for both the controls and
        // every submenu. A single command changes exactly one presentation layer.
        .onExitCommand { handleExitCommand() }.onPlayPauseCommand {
            togglePlayback()
            if !panelVisible { revealControls(focus: .play) }
        }.task(id: item?.id) {
            nextEpisode = await NextEpisodeResolver.resolve(after: item)
        }
    }

    // MARK: - Next episode overlay

    private func nextEpisodeOverlayButton(_ next: MediaItem) -> some View {
        Button {
            onPlayNextEpisode(next)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "forward.end.fill")
                Text("Volgende aflevering").font(.system(size: 18, weight: .semibold))
            }.padding(.horizontal, 24).padding(.vertical, 16)
        }.buttonStyle(VeyraFocusButtonStyle(radius: VeyraRadius.pill)).focused(
            $focused, equals: .nextEpisode
        ).focusSection()
    }

    // MARK: - Playback controls

    private var playbackControls: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom) {
                if let title, !title.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("NU AAN HET KIJKEN").font(.system(size: 12, weight: .semibold))
                            .tracking(2.4).foregroundStyle(VeyraColors.ice.opacity(0.76))

                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(title).font(.system(size: 24, weight: .bold, design: .rounded))
                                .lineLimit(1)

                            if let episodeLabel {
                                Text(episodeLabel).font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundStyle(VeyraColors.cyan)
                                    .lineLimit(1)
                            }
                        }
                    }
                }

                Spacer()

                TimelineView(.periodic(from: .now, by: 30)) { context in
                    Text(context.date.formatted(date: .omitted, time: .shortened)).font(
                        .system(size: 18, weight: .semibold, design: .rounded)
                    ).monospacedDigit().foregroundStyle(.white.opacity(0.72))
                }
            }

            VeyraPlaybackTimeline(
                engine: engine, displayedTime: seekController.previewTime,
                isFocused: focused == .timeline, isSeeking: seekController.isSeeking
            ).contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous)).focusable(
                canSeek
            ).focused($focused, equals: .timeline).focusEffectDisabled().onMoveCommand {
                direction in
                switch direction {
                case .left: requestSeek(by: -30)
                case .right: requestSeek(by: 30)
                case .down: focused = .play
                default: break
                }
            }.accessibilityLabel("Voortgang").accessibilityHint(
                "Links of rechts: dertig seconden springen. Omlaag: afspeelknoppen."
            ).accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: requestSeek(by: 30)
                case .decrement: requestSeek(by: -30)
                @unknown default: break
                }
            }

            HStack(spacing: 22) {
                Color.clear.frame(maxWidth: .infinity, maxHeight: 1)

                Button {
                    openSubtitles()

                } label: {
                    Image(systemName: "captions.bubble").padding(14)
                }.focused($focused, equals: .subtitles)

                Button {
                    requestSeek(by: -30)

                } label: {
                    Image(systemName: "gobackward.30").frame(width: 58, height: 58)
                }.focused($focused, equals: .backward).disabled(!canSeek)

                Button {
                    togglePlayback()

                    revealControls(focus: .play)

                } label: {
                    Image(systemName: engine.state == .playing ? "pause.fill" : "play.fill").font(
                        .system(size: 27)
                    ).frame(width: 70, height: 70).background(
                        VeyraColors.red.opacity(0.22), in: Circle())
                }.focused($focused, equals: .play)

                Button {
                    requestSeek(by: 30)

                } label: {
                    Image(systemName: "goforward.30").frame(width: 58, height: 58)
                }.focused($focused, equals: .forward).disabled(!canSeek)

                Button {
                    openAudio()

                } label: {
                    Image(systemName: "speaker.wave.2").padding(14)
                }.focused($focused, equals: .audio)

                Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
            }.font(.system(size: 19, weight: .medium)).buttonStyle(
                VeyraFocusButtonStyle(radius: VeyraRadius.pill)
            ).focusSection().onMoveCommand { direction in handleTransportMove(direction) }
        }.padding(.horizontal, 22).padding(.vertical, 15).veyraGlass(backgroundOpacity: 0.4)
            .padding(.horizontal, 72).padding(.bottom, 34)
    }

    // MARK: - Audio

    private var audioPanel: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text("Audio").font(.system(size: 32, weight: .semibold))

                Spacer()

                Button("Sluiten", systemImage: "xmark") { closeAudio() }.padding(8).focused(
                    $audioFocused, equals: .close)
            }

            if engine.audioTracks.isEmpty {
                Text("Geen audiotracks beschikbaar voor deze stream.").foregroundStyle(
                    VeyraColors.secondary)

            } else {
                ScrollView {
                    LazyVStack(spacing: 18) {
                        ForEach(engine.audioTracks) { track in
                            Button {
                                engine.selectAudioTrack(index: track.id)

                                closeAudio()

                            } label: {
                                HStack(spacing: 18) {
                                    Image(
                                        systemName: engine.activeAudioTrackIndex == track.id
                                            ? "checkmark.circle.fill" : "circle"
                                    ).foregroundStyle(VeyraColors.cyan)

                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(
                                            track.name.isEmpty
                                                ? "Audiotrack \(track.id + 1)" : track.name)

                                        Text(audioDescription(track)).font(.system(size: 20))
                                            .foregroundStyle(VeyraColors.secondary)
                                    }

                                    Spacer()
                                }.padding(20)
                            }.focused($audioFocused, equals: .track(track.id))
                        }
                    }.padding(8)
                }
            }
        }.padding(28).buttonStyle(VeyraFocusButtonStyle()).veyraGlass().onAppear {
            Task { @MainActor in
                await Task.yield()

                if let first = engine.audioTracks.first {
                    audioFocused = .track(first.id)

                } else {
                    audioFocused = .close
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

    // MARK: - Playback helpers

    private var episodeLabel: String? {
        guard item?.type == .series,
              let season = item?.seasonNumber,
              let episode = item?.episodeNumber
        else { return nil }

        return "S\(season) · A\(episode)"
    }

    private var canSeek: Bool { engine.duration.isFinite && engine.duration > 0 }

    private func requestSeek(by offset: Double) {
        guard canSeek else { return }
        revealControls()

        seekController.request(
            by: offset, currentTime: engine.currentTime, duration: engine.duration
        ) { [engine] target in
            guard engine.duration.isFinite, engine.duration > 0 else { return }
            await engine.seek(to: min(engine.duration, max(0, target)))
        }
    }

    private func handleTransportMove(_ direction: MoveCommandDirection) {
        switch direction {
        case .up: if canSeek { focused = .timeline }
        case .left:
            focused = (focused ?? .play).horizontalNeighbor(forward: false, canSeek: canSeek)
        case .right:
            focused = (focused ?? .play).horizontalNeighbor(forward: true, canSeek: canSeek)
        default: break
        }
        interaction += 1
    }

    private func togglePlayback() {
        if engine.state == .playing {
            engine.pause()

        } else {
            engine.play()
        }
    }

    // MARK: - Back/Menu handling

    private func handleExitCommand() {
        interaction += 1
        switch presentation.handleBack() {
        case .closedPanel(let panel):
            audioFocused = nil
            restoreControlFocus(panel == .subtitles ? .subtitles : .audio)
        case .hidControls: focused = .surface
        case .exitPlayer:
            seekController.cancel()
            onRequestExit()
        }
    }

    // MARK: - Panels

    private func openSubtitles() {
        audioFocused = nil
        focused = nil
        presentation.open(.subtitles)
        interaction += 1
    }

    private func closeSubtitles() {
        guard presentation.close(.subtitles) else { return }
        interaction += 1
        restoreControlFocus(.subtitles)
    }

    private func openAudio() {
        focused = nil
        audioFocused = nil
        presentation.open(.audio)
        interaction += 1
    }

    private func closeAudio() {
        guard presentation.close(.audio) else { return }
        audioFocused = nil
        interaction += 1
        restoreControlFocus(.audio)
    }

    private func restoreControlFocus(_ target: Control) {
        Task { @MainActor in
            await Task.yield()
            guard controlsVisible, !panelVisible else { return }
            focused = target
        }
    }

    private func revealControls(focus target: Control? = nil) {
        presentation.revealControls()
        if let target, !panelVisible { focused = target }
        interaction += 1
    }
}

// MARK: - Timeline

private struct VeyraPlaybackTimeline: View {
    @ObservedObject var engine: AetherEngine

    let displayedTime: Double?
    let isFocused: Bool
    let isSeeking: Bool

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            let rawTime = displayedTime ?? engine.currentTime
            let safeTime = rawTime.isFinite ? max(rawTime, 0) : 0
            let safeDuration = engine.duration.isFinite ? max(engine.duration, 0) : 0
            let currentTime = min(safeTime, safeDuration)

            VStack(spacing: 8) {
                if engine.duration.isFinite && engine.duration > 0 {
                    GeometryReader { geometry in
                        let progress = engine.duration > 0 ? currentTime / engine.duration : 0
                        let rawBuffered = engine.bufferedPosition
                        let safeBuffered = rawBuffered.isFinite ? max(rawBuffered, 0) : 0
                        let bufferedProgress =
                            engine.duration > 0 ? min(1, safeBuffered / engine.duration) : 0

                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.24))

                            Capsule().fill(Color(red: 0.62, green: 0.93, blue: 1.0).opacity(0.5)).frame(
                                width: geometry.size.width * CGFloat(bufferedProgress))

                            Capsule().fill(VeyraColors.red).frame(
                                width: geometry.size.width * CGFloat(progress))

                            if isFocused {
                                Circle().fill(.white).frame(width: 18, height: 18).shadow(
                                    color: VeyraColors.red.opacity(0.75), radius: 10
                                ).offset(
                                    x: max(
                                        0,
                                        min(
                                            geometry.size.width - 18,
                                            geometry.size.width * CGFloat(progress) - 9)))
                            }
                        }
                    }.frame(height: isFocused ? 18 : 7).animation(
                        VeyraAnimation.focus, value: isFocused)

                    HStack {
                        Text(time(currentTime))

                        if displayedTime != nil {
                            Text(isSeeking ? "Spoelen..." : "Nieuwe positie").foregroundStyle(
                                VeyraColors.cyan)
                        } else if isFocused {
                            Text("Links/rechts: 30 sec").foregroundStyle(VeyraColors.cyan)
                        }

                        Spacer()

                        Text(time(engine.duration))
                    }

                } else {
                    HStack(spacing: 10) {
                        Circle().fill(VeyraColors.red).frame(width: 9, height: 9)

                        Text("Stream")

                        Spacer()

                        Text(time(engine.currentTime))
                    }
                }
            }.font(.system(size: 21, weight: .semibold).monospacedDigit()).padding(.horizontal, 11)
                .padding(.vertical, 9).background(
                    isFocused ? VeyraColors.cyan.opacity(0.11) : .clear,
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                ).overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(
                        isFocused ? VeyraColors.cyan : .clear, lineWidth: 2)
                }
        }
    }

    private func time(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0, seconds < Double(Int.max) else { return "—" }

        let total = Int(seconds)

        return String(format: "%d:%02d:%02d", total / 3600, total / 60 % 60, total % 60)
    }
}

// MARK: - Settings panel

private struct SubtitleSettingsPanel: View {
    @ObservedObject var engine: AetherEngine

    var item: MediaItem? = nil

    let onClose: () -> Void

    @AppStorage("veyra.subtitle.size") private var subtitleSizeRaw = VeyraSubtitleSize.normal
        .rawValue

    @AppStorage("veyra.subtitle.position") private var subtitlePositionRaw = VeyraSubtitlePosition
        .low.rawValue

    @AppStorage("veyra.subtitle.background") private var subtitleBackgroundRaw =
        VeyraSubtitleBackground.subtle.rawValue

    @AppStorage("veyra.subtitle.shadow") private var subtitleShadow = true

    @AppStorage("veyra.subtitle.offset") private var subtitleOffset: Double = 0

    @FocusState private var focusedRow: SubtitleSettingsFocus?

    @State private var selectedSection: SubtitleSettingsSection = .tracks

    private enum SubtitleSettingsSection: String, CaseIterable, Hashable {
        case tracks
        case appearance
        case sync

        var title: String {
            switch self {
            case .tracks: return "Ondertitels"

            case .appearance: return "Weergave"

            case .sync: return "Synchronisatie"
            }
        }

        var icon: String {
            switch self {
            case .tracks: return "captions.bubble"

            case .appearance: return "textformat.size"

            case .sync: return "timer"
            }
        }
    }

    private enum SubtitleSettingsFocus: Hashable {
        case section(SubtitleSettingsSection)

        case off

        case track(Int)

        case size
        case position
        case background
        case shadow

        case syncMinusLarge
        case syncMinusSmall
        case syncPlusSmall
        case syncPlusLarge
        case syncReset

        case close
    }

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
        HStack(spacing: 0) {
            sidebar

            Divider().overlay(Color.white.opacity(0.12))

            content
        }.veyraGlass().preferredColorScheme(.dark).onAppear {
            Task { @MainActor in
                await Task.yield()

                focusedRow = .section(.tracks)
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ONDERTITELS").font(.system(size: 17, weight: .semibold)).tracking(2.5)
                .foregroundStyle(.secondary).padding(.horizontal, 22).padding(.top, 44).padding(
                    .bottom, 10)

            ForEach(SubtitleSettingsSection.allCases, id: \.self) { section in sidebarRow(section) }

            Spacer()

            closeRow.padding(.bottom, 30)
        }.frame(width: 235)
    }

    private func sidebarRow(_ section: SubtitleSettingsSection) -> some View {
        let isSelected = selectedSection == section

        let isFocused = focusedRow == .section(section)

        return HStack(spacing: 13) {
            Image(systemName: section.icon).frame(width: 28)

            Text(section.title)

            Spacer()
        }.font(.system(size: 19, weight: isSelected ? .semibold : .regular)).foregroundStyle(
            isFocused ? .white : isSelected ? .cyan : .white.opacity(0.72)
        ).padding(.horizontal, 18).padding(.vertical, 14).background(
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(
                isFocused
                    ? Color.cyan.opacity(0.18) : isSelected ? Color.cyan.opacity(0.07) : Color.clear
            )
        ).overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(
                isFocused ? Color.cyan : Color.clear, lineWidth: 2)
        ).contentShape(Rectangle()).focusable(true).focused($focusedRow, equals: .section(section))
            .focusEffectDisabled().onTapGesture { selectedSection = section }.padding(
                .horizontal, 10)
    }

    private var closeRow: some View {
        let isFocused = focusedRow == .close

        return HStack(spacing: 12) {
            Image(systemName: "xmark")

            Text("Sluiten")

            Spacer()
        }.font(.system(size: 18, weight: .medium)).foregroundStyle(isFocused ? .white : .secondary)
            .padding(.horizontal, 18).padding(.vertical, 13).background(
                RoundedRectangle(cornerRadius: 12).fill(
                    isFocused ? Color.white.opacity(0.10) : Color.clear)
            ).contentShape(Rectangle()).focusable(true).focused($focusedRow, equals: .close)
            .focusEffectDisabled().onTapGesture(perform: onClose).padding(.horizontal, 10)
    }

    // MARK: - Content

    @ViewBuilder private var content: some View {
        switch selectedSection {
        case .tracks: trackContent

        case .appearance: appearanceContent

        case .sync: syncContent
        }
    }

    // MARK: - Tracks

    private var trackContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                contentHeader(title: "Ondertitelspoor", subtitle: "Kies een beschikbaar spoor.")

                OpenSubtitlesSearchView(item: item, engine: engine).padding(.bottom, 20)

                trackOffRow

                ForEach(engine.subtitleTracks) { track in subtitleTrackRow(track) }

                if engine.subtitleTracks.isEmpty && !engine.isLoadingSubtitles {
                    Text("Deze stream biedt momenteel geen selecteerbare ondertitels aan.").font(
                        .system(size: 18)
                    ).foregroundStyle(.secondary).padding(.top, 18)
                }

                if engine.isLoadingSubtitles {
                    HStack(spacing: 12) {
                        ProgressView()

                        Text("Ondertitels laden…").foregroundStyle(.secondary)
                    }.padding(.top, 16)
                }
            }.padding(.horizontal, 34).padding(.vertical, 42)
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var trackOffRow: some View {
        let isSelected = !engine.isSubtitleActive

        let isFocused = focusedRow == .off

        return settingsSelectionRow(
            title: "Uit", subtitle: "Geen ondertitels", systemImage: "captions.bubble.fill",
            selected: isSelected, focused: isFocused
        ).focusable(true).focused($focusedRow, equals: .off).focusEffectDisabled().onTapGesture {
            SubtitleService.shared.userSelectedTrack()
            engine.clearSubtitle()

            engine.clearSecondarySubtitle()
        }
    }

    private func subtitleTrackRow(_ track: TrackInfo) -> some View {
        let isSelected = engine.activeSubtitleTrackIndex == track.id

        let isFocused = focusedRow == .track(track.id)

        return settingsSelectionRow(
            title: title(track), subtitle: details(track), systemImage: "captions.bubble",
            selected: isSelected, focused: isFocused
        ).focusable(true).focused($focusedRow, equals: .track(track.id)).focusEffectDisabled()
            .onTapGesture {
                SubtitleService.shared.userSelectedTrack()
                engine.selectSubtitleTrack(index: track.id)
            }
    }

    // MARK: - Appearance

    private var appearanceContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                contentHeader(
                    title: "Weergave", subtitle: "Pas de ondertitels aan zoals je ze wilt zien.")

                settingsGroup(title: "TEKST") {
                    settingRow(
                        title: "Tekstgrootte", value: subtitleSize.title,
                        systemImage: "textformat.size", focused: focusedRow == .size
                    ).focusable(true).focused($focusedRow, equals: .size).focusEffectDisabled()
                        .onTapGesture { cycleSubtitleSize() }

                    separator

                    settingRow(
                        title: "Achtergrond", value: subtitleBackground.title,
                        systemImage: "rectangle.fill", focused: focusedRow == .background
                    ).focusable(true).focused($focusedRow, equals: .background)
                        .focusEffectDisabled().onTapGesture { cycleBackground() }

                    separator

                    settingRow(
                        title: "Schaduw", value: subtitleShadow ? "Aan" : "Uit",
                        systemImage: "shadow", focused: focusedRow == .shadow
                    ).focusable(true).focused($focusedRow, equals: .shadow).focusEffectDisabled()
                        .onTapGesture { subtitleShadow.toggle() }
                }

                settingsGroup(title: "POSITIE") {
                    settingRow(
                        title: "Plaatsing", value: subtitlePosition.title,
                        systemImage: "rectangle.bottomthird.inset.filled",
                        focused: focusedRow == .position
                    ).focusable(true).focused($focusedRow, equals: .position).focusEffectDisabled()
                        .onTapGesture { cyclePosition() }
                }

                Text(
                    "Deze weergave-instellingen gelden voor tekstondertitels die door Veyra worden getekend. Beeldgebaseerde of native ondertitels kunnen hun eigen positionering bevatten."
                ).font(.system(size: 15)).foregroundStyle(.secondary).fixedSize(
                    horizontal: false, vertical: true)
            }.padding(.horizontal, 34).padding(.vertical, 42)
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Synchronisatie

    private var syncContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                contentHeader(title: "Synchronisatie", subtitle: currentOffsetDescription)

                settingsGroup(title: "VERSCHUIVEN") {
                    syncRow(title: "10 seconden vroeger", systemImage: "gobackward.10", focused: focusedRow == .syncMinusLarge)
                        .focusable(true).focused($focusedRow, equals: .syncMinusLarge)
                        .focusEffectDisabled().onTapGesture { adjustOffset(by: -10.0) }

                    separator

                    syncRow(title: "0,1 seconde vroeger", systemImage: "minus", focused: focusedRow == .syncMinusSmall)
                        .focusable(true).focused($focusedRow, equals: .syncMinusSmall)
                        .focusEffectDisabled().onTapGesture { adjustOffset(by: -0.1) }

                    separator

                    syncRow(title: "0,1 seconde later", systemImage: "plus", focused: focusedRow == .syncPlusSmall)
                        .focusable(true).focused($focusedRow, equals: .syncPlusSmall)
                        .focusEffectDisabled().onTapGesture { adjustOffset(by: 0.1) }

                    separator

                    syncRow(title: "10 seconden later", systemImage: "goforward.10", focused: focusedRow == .syncPlusLarge)
                        .focusable(true).focused($focusedRow, equals: .syncPlusLarge)
                        .focusEffectDisabled().onTapGesture { adjustOffset(by: 10.0) }
                }

                settingsGroup(title: "HERSTELLEN") {
                    syncRow(title: "Terug naar 0,0s", systemImage: "arrow.counterclockwise", focused: focusedRow == .syncReset)
                        .focusable(true).focused($focusedRow, equals: .syncReset)
                        .focusEffectDisabled().onTapGesture { subtitleOffset = 0 }
                }

                Text(
                    "Verschuift het moment waarop tekstondertitels (van Veyra of OpenSubtitles) verschijnen. Handig als ze niet gelijklopen met het geluid. \"Vroeger\" laat ze eerder zien, \"later\" vertraagt ze. Werkt niet voor native ondertitelsporen die rechtstreeks door het toestel worden getekend."
                ).font(.system(size: 15)).foregroundStyle(.secondary).fixedSize(
                    horizontal: false, vertical: true)
            }.padding(.horizontal, 34).padding(.vertical, 42)
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var currentOffsetDescription: String {
        if subtitleOffset == 0 {
            return "Ondertitels lopen gelijk met het geluid."
        }

        let sign = subtitleOffset > 0 ? "+" : ""

        return "Huidige verschuiving: \(sign)\(String(format: "%.1f", subtitleOffset))s"
    }

    private func adjustOffset(by delta: Double) {
        let clamped = min(60, max(-60, subtitleOffset + delta))

        subtitleOffset = (clamped * 10).rounded() / 10
    }

    private func syncRow(title: String, systemImage: String, focused: Bool) -> some View {
        HStack(spacing: 18) {
            Image(systemName: systemImage).font(.system(size: 21)).foregroundStyle(
                focused ? .white : .cyan
            ).frame(width: 32)

            Text(title).font(.system(size: 19)).foregroundStyle(.white)

            Spacer()
        }.padding(.horizontal, 20).padding(.vertical, 17).background(
            focused ? Color.cyan.opacity(0.14) : Color.clear
        ).contentShape(Rectangle())
    }

    // MARK: - Components

    private func contentHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 32, weight: .semibold)).foregroundStyle(.white)

            Text(subtitle).font(.system(size: 17)).foregroundStyle(.secondary)
        }.padding(.bottom, 14)
    }

    private func settingsGroup<Content: View>(title: String, @ViewBuilder content: () -> Content)
        -> some View
    {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 14, weight: .semibold)).tracking(2).foregroundStyle(
                .secondary
            ).padding(.horizontal, 5)

            VStack(spacing: 0, content: content).background(
                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(
                    Color.white.opacity(0.055)))
        }
    }

    private func settingsSelectionRow(
        title: String, subtitle: String, systemImage: String, selected: Bool, focused: Bool
    ) -> some View {
        HStack(spacing: 18) {
            Image(systemName: systemImage).font(.system(size: 22)).foregroundStyle(
                focused ? .white : .cyan
            ).frame(width: 34)

            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 20, weight: selected ? .semibold : .regular))
                    .foregroundStyle(.white)

                if !subtitle.isEmpty {
                    Text(subtitle).font(.system(size: 15)).foregroundStyle(.secondary).lineLimit(2)
                }
            }

            Spacer()

            if selected {
                Image(systemName: "checkmark").font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.cyan)
            }
        }.padding(.horizontal, 20).padding(.vertical, 17).background(
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(
                focused ? Color.cyan.opacity(0.16) : Color.white.opacity(0.035))
        ).overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(
                focused ? Color.cyan : Color.clear, lineWidth: 2)
        ).contentShape(Rectangle())
    }

    private func settingRow(title: String, value: String, systemImage: String, focused: Bool)
        -> some View
    {
        HStack(spacing: 18) {
            Image(systemName: systemImage).font(.system(size: 21)).foregroundStyle(
                focused ? .white : .cyan
            ).frame(width: 32)

            Text(title).font(.system(size: 19)).foregroundStyle(.white)

            Spacer()

            Text(value).font(.system(size: 18)).foregroundStyle(focused ? .white : .secondary)

            Image(systemName: "chevron.right").font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
        }.padding(.horizontal, 20).padding(.vertical, 17).background(
            focused ? Color.cyan.opacity(0.14) : Color.clear
        ).contentShape(Rectangle())
    }

    private var separator: some View {
        Divider().overlay(Color.white.opacity(0.08)).padding(.leading, 70)
    }

    // MARK: - Setting actions

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

    // MARK: - Track labels

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

// MARK: - Subtitle overlay

private struct PlayerSubtitleOverlay: View {
    @ObservedObject var engine: AetherEngine

    @AppStorage("veyra.subtitle.size") private var subtitleSizeRaw = VeyraSubtitleSize.normal
        .rawValue

    @AppStorage("veyra.subtitle.position") private var subtitlePositionRaw = VeyraSubtitlePosition
        .low.rawValue

    @AppStorage("veyra.subtitle.background") private var subtitleBackgroundRaw =
        VeyraSubtitleBackground.subtle.rawValue

    @AppStorage("veyra.subtitle.shadow") private var subtitleShadow = true

    @AppStorage("veyra.subtitle.offset") private var subtitleOffset: Double = 0

    private var subtitleSize: VeyraSubtitleSize {
        VeyraSubtitleSize(rawValue: subtitleSizeRaw) ?? .normal
    }

    private var subtitlePosition: VeyraSubtitlePosition {
        VeyraSubtitlePosition(rawValue: subtitlePositionRaw) ?? .low
    }

    private var subtitleBackground: VeyraSubtitleBackground {
        VeyraSubtitleBackground(rawValue: subtitleBackgroundRaw) ?? .subtle
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
                        }.frame(maxWidth: geometry.size.width * 0.86).padding(
                            .bottom, subtitlePosition.bottomPadding(for: geometry.size.height))
                    }.frame(width: geometry.size.width, height: geometry.size.height)
                }.frame(width: geometry.size.width, height: geometry.size.height)
            }
        }.accessibilityHidden(true)
    }

    private func subtitleText(_ text: String, geometry: GeometryProxy) -> some View {
        let baseSize = max(24, geometry.size.height * 0.038)

        let fontSize = baseSize * subtitleSize.multiplier

        return Text(text).font(.system(size: fontSize, weight: .semibold)).multilineTextAlignment(
            .center
        ).foregroundStyle(.white).shadow(
            color: subtitleShadow ? .black.opacity(0.95) : .clear, radius: subtitleShadow ? 4 : 0,
            x: 1, y: 2
        ).padding(.horizontal, 13).padding(.vertical, 5).background(
            RoundedRectangle(cornerRadius: 6, style: .continuous).fill(
                Color.black.opacity(subtitleBackground.opacity))
        ).fixedSize(horizontal: false, vertical: true)
    }

    private func bitmapView(_ bitmap: SubtitleImage, in size: CGSize) -> some View {
        let source =
            engine.sourceVideoWidth > 0 && engine.sourceVideoHeight > 0
            ? CGSize(
                width: CGFloat(engine.sourceVideoWidth), height: CGFloat(engine.sourceVideoHeight))
            : size

        let pixelAspect = CGFloat(engine.sourceVideoPixelAspectRatio)

        let safePixelAspect = pixelAspect > 0 ? pixelAspect : 1

        let videoScale = min(
            size.width / (source.width * safePixelAspect), size.height / source.height)

        let width = source.width * safePixelAspect * videoScale

        let canvas =
            bitmap.canvasSize.width > 0 && bitmap.canvasSize.height > 0 ? bitmap.canvasSize : source

        let height = canvas.height * width / (canvas.width * safePixelAspect)

        return Image(decorative: bitmap.cgImage, scale: 1).resizable().frame(
            width: bitmap.position.width * width, height: bitmap.position.height * height
        ).position(
            x: (size.width - width) / 2 + bitmap.position.midX * width,

            y: (size.height - height) / 2 + bitmap.position.midY * height)
    }
}
