import SwiftUI
import AetherEngine

// MARK: - Subtitle preferences

private enum VeyraSubtitlePosition: String, CaseIterable {
    case low
    case standard
    case high

    var title: String {
        switch self {
        case .low:
            return "Laag"

        case .standard:
            return "Standaard"

        case .high:
            return "Hoog"
        }
    }

    func bottomPadding(
        for height: CGFloat
    ) -> CGFloat {
        switch self {
        case .low:
            return max(
                42,
                height * 0.045
            )

        case .standard:
            return max(
                70,
                height * 0.075
            )

        case .high:
            return max(
                110,
                height * 0.13
            )
        }
    }
}

private enum VeyraSubtitleSize: String, CaseIterable {
    case small
    case normal
    case large

    var title: String {
        switch self {
        case .small:
            return "Klein"

        case .normal:
            return "Normaal"

        case .large:
            return "Groot"
        }
    }

    var multiplier: CGFloat {
        switch self {
        case .small:
            return 0.82

        case .normal:
            return 1.0

        case .large:
            return 1.22
        }
    }
}

private enum VeyraSubtitleBackground: String, CaseIterable {
    case none
    case subtle
    case strong

    var title: String {
        switch self {
        case .none:
            return "Geen"

        case .subtle:
            return "Subtiel"

        case .strong:
            return "Donker"
        }
    }

    var opacity: Double {
        switch self {
        case .none:
            return 0

        case .subtle:
            return 0.42

        case .strong:
            return 0.70
        }
    }
}

// MARK: - Player controls

/// Playback stays mounted while the user opens or closes the subtitle panel.
struct PlayerSubtitleControls: View {
    @ObservedObject var engine: AetherEngine

    @State private var controlsVisible =
        true

    @State private var showingSubtitles =
        false

    @State private var interaction =
        0

    @FocusState
    private var focused:
        Control?

    private enum Control:
        Hashable
    {
        case surface
        case subtitles
    }

    var body: some View {
        ZStack(
            alignment: .topTrailing
        ) {
            Color.clear
                .contentShape(
                    Rectangle()
                )
                .focusable(
                    !showingSubtitles
                )
                .focused(
                    $focused,
                    equals: .surface
                )
                .focusEffectDisabled()
                .onTapGesture {
                    revealControls()
                }

            PlayerSubtitleOverlay(
                engine: engine
            )
            .allowsHitTesting(
                false
            )

            if controlsVisible
                && !showingSubtitles
            {
                subtitleButton
            }
        }
        .onMoveCommand { _ in
            if !showingSubtitles {
                revealControls()
            }
        }
        .onPlayPauseCommand {
            if engine.state == .playing {
                engine.pause()
            } else {
                engine.play()
            }
        }
        .onAppear {
            focused =
                .subtitles
        }
        .task(
            id: interaction
        ) {
            guard
                !showingSubtitles
            else {
                return
            }

            do {
                try await Task.sleep(
                    for: .seconds(6)
                )
            } catch {
                return
            }

            guard
                !showingSubtitles
            else {
                return
            }

            controlsVisible =
                false

            focused =
                .surface
        }
        .overlay(
            alignment: .trailing
        ) {
            if showingSubtitles {
                SubtitleSettingsPanel(
                    engine: engine
                ) {
                    showingSubtitles =
                        false

                    revealControls()
                }
                .frame(
                    width: 720
                )
            }
        }
    }

    // MARK: - Subtitle button

    private var subtitleButton:
        some View
    {
        Button {
            showingSubtitles =
                true

            controlsVisible =
                true

            interaction += 1

        } label: {
            HStack(
                spacing: 12
            ) {
                Image(
                    systemName:
                        "captions.bubble"
                )

                Text(
                    "Ondertitels"
                )
            }
            .font(
                .system(
                    size: 21,
                    weight: .semibold
                )
            )
            .padding(
                .horizontal,
                20
            )
            .padding(
                .vertical,
                13
            )
        }
        .focused(
            $focused,
            equals: .subtitles
        )
        .padding(
            .top,
            55
        )
        .padding(
            .trailing,
            65
        )
    }

    // MARK: - Controls

    private func revealControls() {
        controlsVisible =
            true

        focused =
            .subtitles

        interaction += 1
    }
}

// MARK: - Settings panel

private struct SubtitleSettingsPanel: View {
    @ObservedObject var engine:
        AetherEngine

    let onClose:
        () -> Void

    @AppStorage(
        "veyra.subtitle.size"
    )
    private var subtitleSizeRaw =
        VeyraSubtitleSize
            .normal
            .rawValue

    @AppStorage(
        "veyra.subtitle.position"
    )
    private var subtitlePositionRaw =
        VeyraSubtitlePosition
            .low
            .rawValue

    @AppStorage(
        "veyra.subtitle.background"
    )
    private var subtitleBackgroundRaw =
        VeyraSubtitleBackground
            .subtle
            .rawValue

    @AppStorage(
        "veyra.subtitle.shadow"
    )
    private var subtitleShadow =
        true

    @FocusState
    private var focusedRow:
        SubtitleSettingsFocus?

    @State private var selectedSection:
        SubtitleSettingsSection =
            .tracks

    private enum SubtitleSettingsSection:
        String,
        CaseIterable,
        Hashable
    {
        case tracks
        case appearance

        var title:
            String
        {
            switch self {
            case .tracks:
                return
                    "Ondertitels"

            case .appearance:
                return
                    "Weergave"
            }
        }

        var icon:
            String
        {
            switch self {
            case .tracks:
                return
                    "captions.bubble"

            case .appearance:
                return
                    "textformat.size"
            }
        }
    }

    private enum SubtitleSettingsFocus:
        Hashable
    {
        case section(
            SubtitleSettingsSection
        )

        case off

        case track(
            Int
        )

        case size

        case position

        case background

        case shadow

        case close
    }

    private var subtitleSize:
        VeyraSubtitleSize
    {
        VeyraSubtitleSize(
            rawValue:
                subtitleSizeRaw
        )
        ?? .normal
    }

    private var subtitlePosition:
        VeyraSubtitlePosition
    {
        VeyraSubtitlePosition(
            rawValue:
                subtitlePositionRaw
        )
        ?? .low
    }

    private var subtitleBackground:
        VeyraSubtitleBackground
    {
        VeyraSubtitleBackground(
            rawValue:
                subtitleBackgroundRaw
        )
        ?? .subtle
    }

    var body: some View {
        HStack(
            spacing: 0
        ) {
            sidebar

            Divider()
                .overlay(
                    Color.white.opacity(
                        0.12
                    )
                )

            content
        }
        .background(
            Color(
                red: 0.035,
                green: 0.055,
                blue: 0.075
            )
            .opacity(
                0.97
            )
        )
        .preferredColorScheme(
            .dark
        )
        .onExitCommand(
            perform: onClose
        )
        .onAppear {
            focusedRow =
                .section(
                    .tracks
                )
        }
    }

    // MARK: - Sidebar

    private var sidebar:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            Text(
                "ONDERTITELS"
            )
            .font(
                .system(
                    size: 17,
                    weight: .semibold
                )
            )
            .tracking(
                2.5
            )
            .foregroundStyle(
                .secondary
            )
            .padding(
                .horizontal,
                22
            )
            .padding(
                .top,
                44
            )
            .padding(
                .bottom,
                10
            )

            ForEach(
                SubtitleSettingsSection
                    .allCases,
                id: \.self
            ) { section in
                sidebarRow(
                    section
                )
            }

            Spacer()

            closeRow
                .padding(
                    .bottom,
                    30
                )
        }
        .frame(
            width: 235
        )
    }

    private func sidebarRow(
        _ section:
            SubtitleSettingsSection
    ) -> some View {
        let isSelected =
            selectedSection ==
                section

        let isFocused =
            focusedRow ==
                .section(
                    section
                )

        return HStack(
            spacing: 13
        ) {
            Image(
                systemName:
                    section.icon
            )
            .frame(
                width: 28
            )

            Text(
                section.title
            )

            Spacer()
        }
        .font(
            .system(
                size: 19,
                weight:
                    isSelected
                    ? .semibold
                    : .regular
            )
        )
        .foregroundStyle(
            isFocused
                ? .white
                : isSelected
                    ? .cyan
                    : .white.opacity(
                        0.72
                    )
        )
        .padding(
            .horizontal,
            18
        )
        .padding(
            .vertical,
            14
        )
        .background(
            RoundedRectangle(
                cornerRadius: 12,
                style: .continuous
            )
            .fill(
                isFocused
                    ? Color.cyan.opacity(
                        0.18
                    )
                    : isSelected
                        ? Color.cyan.opacity(
                            0.07
                        )
                        : Color.clear
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 12,
                style: .continuous
            )
            .strokeBorder(
                isFocused
                    ? Color.cyan
                    : Color.clear,
                lineWidth: 2
            )
        )
        .contentShape(
            Rectangle()
        )
        .focusable(
            true
        )
        .focused(
            $focusedRow,
            equals:
                .section(
                    section
                )
        )
        .focusEffectDisabled()
        .onTapGesture {
            selectedSection =
                section
        }
        .padding(
            .horizontal,
            10
        )
    }

    private var closeRow:
        some View
    {
        let isFocused =
            focusedRow ==
                .close

        return HStack(
            spacing: 12
        ) {
            Image(
                systemName:
                    "xmark"
            )

            Text(
                "Sluiten"
            )

            Spacer()
        }
        .font(
            .system(
                size: 18,
                weight: .medium
            )
        )
        .foregroundStyle(
            isFocused
                ? .white
                : .secondary
        )
        .padding(
            .horizontal,
            18
        )
        .padding(
            .vertical,
            13
        )
        .background(
            RoundedRectangle(
                cornerRadius: 12
            )
            .fill(
                isFocused
                    ? Color.white.opacity(
                        0.10
                    )
                    : Color.clear
            )
        )
        .contentShape(
            Rectangle()
        )
        .focusable(
            true
        )
        .focused(
            $focusedRow,
            equals:
                .close
        )
        .focusEffectDisabled()
        .onTapGesture(
            perform:
                onClose
        )
        .padding(
            .horizontal,
            10
        )
    }

    // MARK: - Content

    @ViewBuilder
    private var content:
        some View
    {
        switch selectedSection {
        case .tracks:
            trackContent

        case .appearance:
            appearanceContent
        }
    }

    // MARK: - Tracks

    private var trackContent:
        some View
    {
        ScrollView(
            .vertical,
            showsIndicators:
                false
        ) {
            VStack(
                alignment: .leading,
                spacing: 14
            ) {
                contentHeader(
                    title:
                        "Ondertitelspoor",
                    subtitle:
                        "Kies een beschikbaar spoor."
                )

                trackOffRow

                ForEach(
                    engine.subtitleTracks
                ) { track in
                    subtitleTrackRow(
                        track
                    )
                }

                if engine
                    .subtitleTracks
                    .isEmpty
                    && !engine
                        .isLoadingSubtitles
                {
                    Text(
                        "Deze stream biedt momenteel geen selecteerbare ondertitels aan."
                    )
                    .font(
                        .system(
                            size: 18
                        )
                    )
                    .foregroundStyle(
                        .secondary
                    )
                    .padding(
                        .top,
                        18
                    )
                }

                if engine
                    .isLoadingSubtitles
                {
                    HStack(
                        spacing: 12
                    ) {
                        ProgressView()

                        Text(
                            "Ondertitels laden…"
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }
                    .padding(
                        .top,
                        16
                    )
                }
            }
            .padding(
                .horizontal,
                34
            )
            .padding(
                .vertical,
                42
            )
        }
        .frame(
            maxWidth:
                .infinity,
            maxHeight:
                .infinity,
            alignment:
                .topLeading
        )
    }

    private var trackOffRow:
        some View
    {
        let isSelected =
            !engine
                .isSubtitleActive

        let isFocused =
            focusedRow ==
                .off

        return settingsSelectionRow(
            title:
                "Uit",
            subtitle:
                "Geen ondertitels",
            systemImage:
                "captions.bubble.fill",
            selected:
                isSelected,
            focused:
                isFocused
        )
        .focusable(
            true
        )
        .focused(
            $focusedRow,
            equals: .off
        )
        .focusEffectDisabled()
        .onTapGesture {
            engine.clearSubtitle()
            engine
                .clearSecondarySubtitle()
        }
    }

    private func subtitleTrackRow(
        _ track:
            TrackInfo
    ) -> some View {
        let isSelected =
            engine
                .activeSubtitleTrackIndex
                == track.id

        let isFocused =
            focusedRow ==
                .track(
                    track.id
                )

        return settingsSelectionRow(
            title:
                title(
                    track
                ),
            subtitle:
                details(
                    track
                ),
            systemImage:
                "captions.bubble",
            selected:
                isSelected,
            focused:
                isFocused
        )
        .focusable(
            true
        )
        .focused(
            $focusedRow,
            equals:
                .track(
                    track.id
                )
        )
        .focusEffectDisabled()
        .onTapGesture {
            engine
                .selectSubtitleTrack(
                    index:
                        track.id
                )
        }
    }

    // MARK: - Appearance

    private var appearanceContent:
        some View
    {
        ScrollView(
            .vertical,
            showsIndicators:
                false
        ) {
            VStack(
                alignment: .leading,
                spacing: 28
            ) {
                contentHeader(
                    title:
                        "Weergave",
                    subtitle:
                        "Pas de ondertitels aan zoals je ze wilt zien."
                )

                settingsGroup(
                    title:
                        "TEKST"
                ) {
                    settingRow(
                        title:
                            "Tekstgrootte",
                        value:
                            subtitleSize
                                .title,
                        systemImage:
                            "textformat.size",
                        focused:
                            focusedRow ==
                                .size
                    )
                    .focusable(
                        true
                    )
                    .focused(
                        $focusedRow,
                        equals:
                            .size
                    )
                    .focusEffectDisabled()
                    .onTapGesture {
                        cycleSubtitleSize()
                    }

                    separator

                    settingRow(
                        title:
                            "Achtergrond",
                        value:
                            subtitleBackground
                                .title,
                        systemImage:
                            "rectangle.fill",
                        focused:
                            focusedRow ==
                                .background
                    )
                    .focusable(
                        true
                    )
                    .focused(
                        $focusedRow,
                        equals:
                            .background
                    )
                    .focusEffectDisabled()
                    .onTapGesture {
                        cycleBackground()
                    }

                    separator

                    settingRow(
                        title:
                            "Schaduw",
                        value:
                            subtitleShadow
                                ? "Aan"
                                : "Uit",
                        systemImage:
                            "shadow",
                        focused:
                            focusedRow ==
                                .shadow
                    )
                    .focusable(
                        true
                    )
                    .focused(
                        $focusedRow,
                        equals:
                            .shadow
                    )
                    .focusEffectDisabled()
                    .onTapGesture {
                        subtitleShadow
                            .toggle()
                    }
                }

                settingsGroup(
                    title:
                        "POSITIE"
                ) {
                    settingRow(
                        title:
                            "Plaatsing",
                        value:
                            subtitlePosition
                                .title,
                        systemImage:
                            "rectangle.bottomthird.inset.filled",
                        focused:
                            focusedRow ==
                                .position
                    )
                    .focusable(
                        true
                    )
                    .focused(
                        $focusedRow,
                        equals:
                            .position
                    )
                    .focusEffectDisabled()
                    .onTapGesture {
                        cyclePosition()
                    }
                }

                Text(
                    "Deze weergave-instellingen gelden voor tekstondertitels die door Veyra worden getekend. Beeldgebaseerde of native ondertitels kunnen hun eigen positionering bevatten."
                )
                .font(
                    .system(
                        size: 15
                    )
                )
                .foregroundStyle(
                    .secondary
                )
                .fixedSize(
                    horizontal:
                        false,
                    vertical:
                        true
                )
            }
            .padding(
                .horizontal,
                34
            )
            .padding(
                .vertical,
                42
            )
        }
        .frame(
            maxWidth:
                .infinity,
            maxHeight:
                .infinity,
            alignment:
                .topLeading
        )
    }

    // MARK: - Settings components

    private func contentHeader(
        title: String,
        subtitle: String
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            Text(
                title
            )
            .font(
                .system(
                    size: 32,
                    weight: .semibold
                )
            )
            .foregroundStyle(
                .white
            )

            Text(
                subtitle
            )
            .font(
                .system(
                    size: 17
                )
            )
            .foregroundStyle(
                .secondary
            )
        }
        .padding(
            .bottom,
            14
        )
    }

    private func settingsGroup<Content: View>(
        title: String,
        @ViewBuilder content:
            () -> Content
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            Text(
                title
            )
            .font(
                .system(
                    size: 14,
                    weight: .semibold
                )
            )
            .tracking(
                2
            )
            .foregroundStyle(
                .secondary
            )
            .padding(
                .horizontal,
                5
            )

            VStack(
                spacing: 0,
                content:
                    content
            )
            .background(
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
                .fill(
                    Color.white
                        .opacity(
                            0.055
                        )
                )
            )
        }
    }

    private func settingsSelectionRow(
        title: String,
        subtitle: String,
        systemImage: String,
        selected: Bool,
        focused: Bool
    ) -> some View {
        HStack(
            spacing: 18
        ) {
            Image(
                systemName:
                    systemImage
            )
            .font(
                .system(
                    size: 22
                )
            )
            .foregroundStyle(
                focused
                    ? .white
                    : .cyan
            )
            .frame(
                width: 34
            )

            VStack(
                alignment: .leading,
                spacing: 5
            ) {
                Text(
                    title
                )
                .font(
                    .system(
                        size: 20,
                        weight:
                            selected
                            ? .semibold
                            : .regular
                    )
                )
                .foregroundStyle(
                    .white
                )

                if !subtitle.isEmpty {
                    Text(
                        subtitle
                    )
                    .font(
                        .system(
                            size: 15
                        )
                    )
                    .foregroundStyle(
                        .secondary
                    )
                    .lineLimit(
                        2
                    )
                }
            }

            Spacer()

            if selected {
                Image(
                    systemName:
                        "checkmark"
                )
                .font(
                    .system(
                        size: 20,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    .cyan
                )
            }
        }
        .padding(
            .horizontal,
            20
        )
        .padding(
            .vertical,
            17
        )
        .background(
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
            .fill(
                focused
                    ? Color.cyan.opacity(
                        0.16
                    )
                    : Color.white.opacity(
                        0.035
                    )
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
            .strokeBorder(
                focused
                    ? Color.cyan
                    : Color.clear,
                lineWidth: 2
            )
        )
        .contentShape(
            Rectangle()
        )
    }

    private func settingRow(
        title: String,
        value: String,
        systemImage: String,
        focused: Bool
    ) -> some View {
        HStack(
            spacing: 18
        ) {
            Image(
                systemName:
                    systemImage
            )
            .font(
                .system(
                    size: 21
                )
            )
            .foregroundStyle(
                focused
                    ? .white
                    : .cyan
            )
            .frame(
                width: 32
            )

            Text(
                title
            )
            .font(
                .system(
                    size: 19
                )
            )
            .foregroundStyle(
                .white
            )

            Spacer()

            Text(
                value
            )
            .font(
                .system(
                    size: 18
                )
            )
            .foregroundStyle(
                focused
                    ? .white
                    : .secondary
            )

            Image(
                systemName:
                    "chevron.right"
            )
            .font(
                .system(
                    size: 15,
                    weight: .semibold
                )
            )
            .foregroundStyle(
                .secondary
            )
        }
        .padding(
            .horizontal,
            20
        )
        .padding(
            .vertical,
            17
        )
        .background(
            focused
                ? Color.cyan.opacity(
                    0.14
                )
                : Color.clear
        )
        .contentShape(
            Rectangle()
        )
    }

    private var separator:
        some View
    {
        Divider()
            .overlay(
                Color.white.opacity(
                    0.08
                )
            )
            .padding(
                .leading,
                70
            )
    }

    // MARK: - Setting actions

    private func cycleSubtitleSize() {
        switch subtitleSize {
        case .small:
            subtitleSizeRaw =
                VeyraSubtitleSize
                    .normal
                    .rawValue

        case .normal:
            subtitleSizeRaw =
                VeyraSubtitleSize
                    .large
                    .rawValue

        case .large:
            subtitleSizeRaw =
                VeyraSubtitleSize
                    .small
                    .rawValue
        }
    }

    private func cyclePosition() {
        switch subtitlePosition {
        case .low:
            subtitlePositionRaw =
                VeyraSubtitlePosition
                    .standard
                    .rawValue

        case .standard:
            subtitlePositionRaw =
                VeyraSubtitlePosition
                    .high
                    .rawValue

        case .high:
            subtitlePositionRaw =
                VeyraSubtitlePosition
                    .low
                    .rawValue
        }
    }

    private func cycleBackground() {
        switch subtitleBackground {
        case .none:
            subtitleBackgroundRaw =
                VeyraSubtitleBackground
                    .subtle
                    .rawValue

        case .subtle:
            subtitleBackgroundRaw =
                VeyraSubtitleBackground
                    .strong
                    .rawValue

        case .strong:
            subtitleBackgroundRaw =
                VeyraSubtitleBackground
                    .none
                    .rawValue
        }
    }

    // MARK: - Track labels

    private func title(
        _ track:
            TrackInfo
    ) -> String {
        if let language =
            track.language,
           !language.isEmpty,
           language != "und"
        {
            return Locale(
                identifier:
                    "nl"
            )
            .localizedString(
                forLanguageCode:
                    language
            )
            ?? language
        }

        return
            track.name.isEmpty
                ? "Ondertitelspoor \(track.id)"
                : track.name
    }

    private func details(
        _ track:
            TrackInfo
    ) -> String {
        var parts =
            [
                track.name,
                track.codec
                    .uppercased()
            ]
            .filter {
                !$0.isEmpty
            }

        if track.isForced {
            parts.append(
                "Alleen anderstalige dialoog"
            )
        }

        if track.isHearingImpaired {
            parts.append(
                "SDH"
            )
        }

        return parts.joined(
            separator:
                " · "
        )
    }
}

// MARK: - Subtitle overlay

private struct PlayerSubtitleOverlay: View {
    @ObservedObject var engine:
        AetherEngine

    @AppStorage(
        "veyra.subtitle.size"
    )
    private var subtitleSizeRaw =
        VeyraSubtitleSize
            .normal
            .rawValue

    @AppStorage(
        "veyra.subtitle.position"
    )
    private var subtitlePositionRaw =
        VeyraSubtitlePosition
            .low
            .rawValue

    @AppStorage(
        "veyra.subtitle.background"
    )
    private var subtitleBackgroundRaw =
        VeyraSubtitleBackground
            .subtle
            .rawValue

    @AppStorage(
        "veyra.subtitle.shadow"
    )
    private var subtitleShadow =
        true

    private var subtitleSize:
        VeyraSubtitleSize
    {
        VeyraSubtitleSize(
            rawValue:
                subtitleSizeRaw
        )
        ?? .normal
    }

    private var subtitlePosition:
        VeyraSubtitlePosition
    {
        VeyraSubtitlePosition(
            rawValue:
                subtitlePositionRaw
        )
        ?? .low
    }

    private var subtitleBackground:
        VeyraSubtitleBackground
    {
        VeyraSubtitleBackground(
            rawValue:
                subtitleBackgroundRaw
        )
        ?? .subtle
    }

    private var usesNativeRendering:
        Bool
    {
        engine.subtitleTracks.first {
            $0.id ==
                engine
                    .activeSubtitleTrackIndex
        }?
        .isNativelyRenderedSubtitle
        == true
    }

    var body: some View {
        GeometryReader {
            geometry in

            TimelineView(
                .periodic(
                    from: .now,
                    by: 0.1
                )
            ) { _ in
                let cues =
                    engine.isSubtitleActive
                        && !usesNativeRendering
                    ? engine.subtitleCues
                        .filter {
                            $0.startTime
                                <= engine.sourceTime
                            &&
                            engine.sourceTime
                                < $0.endTime
                        }
                    : []

                ZStack {
                    // Beeldondertitels behouden
                    // hun originele canvaspositie.
                    ForEach(
                        cues
                    ) { cue in
                        if case .image(
                            let bitmap
                        ) = cue.body
                        {
                            bitmapView(
                                bitmap,
                                in:
                                    geometry
                                        .size
                            )
                        }
                    }

                    // Tekstondertitels worden
                    // bewust onderaan geplaatst.
                    VStack {
                        Spacer(
                            minLength: 0
                        )

                        VStack(
                            spacing: 6
                        ) {
                            ForEach(
                                cues
                            ) { cue in
                                if let text =
                                    cue.text,
                                   !text.isEmpty
                                {
                                    subtitleText(
                                        text,
                                        geometry:
                                            geometry
                                    )
                                }
                            }
                        }
                        .frame(
                            maxWidth:
                                geometry
                                    .size
                                    .width
                                * 0.86
                        )
                        .padding(
                            .bottom,
                            subtitlePosition
                                .bottomPadding(
                                    for:
                                        geometry
                                            .size
                                            .height
                                )
                        )
                    }
                    .frame(
                        width:
                            geometry
                                .size
                                .width,
                        height:
                            geometry
                                .size
                                .height
                    )
                }
                .frame(
                    width:
                        geometry
                            .size
                            .width,
                    height:
                        geometry
                            .size
                            .height
                )
            }
        }
        .accessibilityHidden(
            true
        )
    }

    // MARK: - Text subtitle

    private func subtitleText(
        _ text: String,
        geometry:
            GeometryProxy
    ) -> some View {
        let baseSize =
            max(
                24,
                geometry
                    .size
                    .height
                * 0.038
            )

        let fontSize =
            baseSize
            * subtitleSize
                .multiplier

        return Text(
            text
        )
        .font(
            .system(
                size: fontSize,
                weight: .semibold
            )
        )
        .multilineTextAlignment(
            .center
        )
        .foregroundStyle(
            .white
        )
        .shadow(
            color:
                subtitleShadow
                ? .black.opacity(
                    0.95
                )
                : .clear,
            radius:
                subtitleShadow
                ? 4
                : 0,
            x: 1,
            y: 2
        )
        .padding(
            .horizontal,
            13
        )
        .padding(
            .vertical,
            5
        )
        .background(
            RoundedRectangle(
                cornerRadius: 6,
                style: .continuous
            )
            .fill(
                Color.black.opacity(
                    subtitleBackground
                        .opacity
                )
            )
        )
        .fixedSize(
            horizontal:
                false,
            vertical:
                true
        )
    }

    // MARK: - Bitmap subtitle

    private func bitmapView(
        _ bitmap:
            SubtitleImage,
        in size:
            CGSize
    ) -> some View {
        let source =
            engine.sourceVideoWidth > 0
            && engine.sourceVideoHeight > 0
            ? CGSize(
                width:
                    CGFloat(
                        engine
                            .sourceVideoWidth
                    ),
                height:
                    CGFloat(
                        engine
                            .sourceVideoHeight
                    )
            )
            : size

        let pixelAspect =
            CGFloat(
                engine
                    .sourceVideoPixelAspectRatio
            )

        let safePixelAspect =
            pixelAspect > 0
                ? pixelAspect
                : 1

        let videoScale =
            min(
                size.width
                    / (
                        source.width
                        * safePixelAspect
                    ),
                size.height
                    / source.height
            )

        let width =
            source.width
            * safePixelAspect
            * videoScale

        let canvas =
            bitmap.canvasSize.width > 0
            && bitmap.canvasSize.height > 0
            ? bitmap.canvasSize
            : source

        let height =
            canvas.height
            * width
            / (
                canvas.width
                * safePixelAspect
            )

        return Image(
            decorative:
                bitmap.cgImage,
            scale: 1
        )
        .resizable()
        .frame(
            width:
                bitmap
                    .position
                    .width
                * width,
            height:
                bitmap
                    .position
                    .height
                * height
        )
        .position(
            x:
                (
                    size.width
                    - width
                )
                / 2
                + bitmap
                    .position
                    .midX
                * width,

            y:
                (
                    size.height
                    - height
                )
                / 2
                + bitmap
                    .position
                    .midY
                * height
        )
    }
}
