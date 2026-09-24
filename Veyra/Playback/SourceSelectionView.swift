import SwiftUI

@MainActor
struct SourceSelectionView: View {
    let item: MediaItem

    @ObservedObject
    private var traktStore = TraktStore.shared

    @State
    private var sources: [ResolvedSource] = []

    @State
    private var isLoadingAddons = false

    @State
    private var isLoadingIPTV = false

    @State
    private var hasLoaded = false

    @State
    private var selectedSource: PlayableSource?

    @State
    private var reloadID = UUID()

    @State
    private var selectedFilter: SourceFilter = .all

    // "Eerste bron automatisch selecteren" (Afspelen-instellingen).
    @AppStorage(PlaybackSettingsDefaults.autoSelectFirstSourceKey)
    private var autoSelectFirstSource = false

    @FocusState
    private var focusedSourceID: UUID?

    @FocusState
    private var focusedFilterID: String?

    @FocusState
    private var retryFocused: Bool

    private let resolver =
        SourceResolver()

    var body: some View {
        ZStack {
            background

            VStack(
                alignment: .leading,
                spacing: 24
            ) {
                header

                filterBar

                loadingStatus

                content

                Spacer(
                    minLength: 0
                )
            }
            .padding(
                .horizontal,
                42
            )
            .padding(
                .vertical,
                32
            )
        }
        .task(
            id: reloadID
        ) {
            await loadSources()
        }
        .onChange(of: hasLoaded) { _, loaded in
            guard loaded, autoSelectFirstSource, selectedSource == nil,
                  let first = sources.first
            else { return }
            selectedSource = first.source
        }
        .navigationDestination(
            item: $selectedSource
        ) { source in
            PlayerView(
                source: source,
                item: item,
                resumeProgress:
                    traktStore.progress(
                        for: item
                    )
            )
        }
    }

    // MARK: - Filter

    private enum SourceFilter:
        Hashable
    {
        case all
        case iptv
        case origin(String)

        var id: String {
            switch self {
            case .all:
                return "all"

            case .iptv:
                return "iptv"

            case .origin(
                let name
            ):
                return
                    "origin:\(name)"
            }
        }
    }

    private var filters:
        [SourceFilter]
    {
        var result:
            [SourceFilter] = [
                .all
            ]

        // IPTV VOD beschikbaar bij
        // films én series/afleveringen.
        if item.type == .movie
            || item.type == .series
        {
            result.append(
                .iptv
            )
        }

        var names:
            [String] = []

        for resolved
            in sources
        {
            guard
                resolved.source.kind
                    != .iptvVOD
            else {
                continue
            }

            let name =
                resolved.originName
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )

            guard
                !name.isEmpty
            else {
                continue
            }

            let alreadyExists =
                names.contains {
                    $0.caseInsensitiveCompare(
                        name
                    ) == .orderedSame
                }

            if !alreadyExists {
                names.append(
                    name
                )
            }
        }

        names.sort {
            $0.localizedStandardCompare(
                $1
            ) == .orderedAscending
        }

        for name in names {
            result.append(
                .origin(
                    name
                )
            )
        }

        return result
    }

    /// True als er onder deze originName (filtertab) minstens één bron zit
    /// die via VeyraHub is opgehaald — bepaalt of de filterknop het kleine
    /// hub-icoon toont.
    private func isHubOrigin(
        _ name: String
    ) -> Bool {
        sources.contains {
            $0.isFromHub
                && $0.originName
                    .caseInsensitiveCompare(name)
                    == .orderedSame
        }
    }

    private var filteredSources:
        [ResolvedSource]
    {
        switch selectedFilter {
        case .all:
            return sources

        case .iptv:
            return sources.filter {
                $0.source.kind
                    == .iptvVOD
            }

        case .origin(
            let selectedName
        ):
            return sources.filter {
                $0.source.kind
                    != .iptvVOD
                &&
                $0.originName
                    .caseInsensitiveCompare(
                        selectedName
                    ) == .orderedSame
            }
        }
    }

    // MARK: - Background

    private var background:
        some View
    {
        VeyraBackground()
    }

    // MARK: - Header

    private var header:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            Text("Selecteer bron")
            .font(.system(size: 48, weight: .bold, design: .rounded))
            .foregroundStyle(
                .white
            )

            Text(
                item.title
            )
            .font(
                .system(
                    size: 27,
                    weight: .semibold
                )
            )
            .foregroundStyle(
                .cyan
            )
            .lineLimit(1)

            Text(
                mediaDescription
            )
            .font(
                .system(
                    size: 19
                )
            )
            .foregroundStyle(
                .white.opacity(
                    0.55
                )
            )
        }
    }

    // MARK: - Filter bar

    private var filterBar:
        some View
    {
        ScrollView(
            .horizontal,
            showsIndicators: false
        ) {
            HStack(
                spacing: 14
            ) {
                ForEach(
                    filters,
                    id: \.id
                ) { filter in
                    filterControl(
                        filter
                    )
                }
            }
            .padding(
                .horizontal,
                2
            )
            .padding(
                .vertical,
                6
            )
        }
        .scrollClipDisabled()
        .focusSection()
    }

    private func filterControl(
        _ filter:
            SourceFilter
    ) -> some View {
        let isSelected =
            selectedFilter
                == filter

        let isFocused =
            focusedFilterID
                == filter.id

        // Een addonbron die via VeyraHub loopt krijgt hier een klein
        // hub-icoon, zodat "NinjaCentral" (bv.) herkenbaar blijft als een
        // VeyraHub-addon en niet lijkt op een gelijknamige, lokaal
        // geïnstalleerde addon.
        let showsHubIcon: Bool = {
            if case .origin(let name) = filter {
                return isHubOrigin(name)
            }
            return false
        }()

        return HStack(spacing: 8) {
            if showsHubIcon {
                Image(systemName: "server.rack")
                    .font(.system(size: 15, weight: .semibold))
            }

            Text(
                filterTitle(
                    filter
                )
            )
        }
        .font(
            .system(
                size: 21,
                weight:
                    isSelected
                    ? .bold
                    : .semibold
            )
        )
        .foregroundStyle(
            isSelected
                || isFocused
                ? .white
                : .cyan
        )
        .padding(
            .horizontal,
            25
        )
        .padding(
            .vertical,
            13
        )
        .background(
            Capsule()
                .fill(
                    isSelected
                    ? Color.cyan
                        .opacity(
                            0.25
                        )
                    : isFocused
                        ? Color.cyan
                            .opacity(
                                0.14
                            )
                        : Color.cyan
                            .opacity(
                                0.04
                            )
                )
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    isSelected
                        || isFocused
                        ? Color.cyan
                        : Color.cyan
                            .opacity(
                                0.16
                            ),
                    lineWidth:
                        isFocused
                        ? 2
                        : 1
                )
        )
        .contentShape(
            Capsule()
        )
        .focusable(true)
        .focused(
            $focusedFilterID,
            equals:
                filter.id
        )
        .focusEffectDisabled()
        .scaleEffect(
            isFocused
                ? 1.04
                : 1
        )
        .animation(
            .easeOut(
                duration: 0.12
            ),
            value:
                isFocused
        )
        .onTapGesture {
            selectedFilter =
                filter
        }
    }

    private func filterTitle(
        _ filter:
            SourceFilter
    ) -> String {
        switch filter {
        case .all:
            return "Alle"

        case .iptv:
            return "IPTV"

        case .origin(
            let name
        ):
            return name
        }
    }

    // MARK: - Loading

    @ViewBuilder
    private var loadingStatus:
        some View
    {
        if isLoadingAddons {
            HStack(
                spacing: 12
            ) {
                ProgressView()
                    .scaleEffect(
                        0.75
                    )

                Text(
                    "Addonbronnen zoeken…"
                )
                .font(
                    .system(
                        size: 18
                    )
                )
                .foregroundStyle(
                    .white.opacity(
                        0.60
                    )
                )
            }

        } else if isLoadingIPTV {
            HStack(
                spacing: 12
            ) {
                ProgressView()
                    .scaleEffect(
                        0.65
                    )

                Text(
                    "IPTV VOD wordt toegevoegd…"
                )
                .font(
                    .system(
                        size: 17
                    )
                )
                .foregroundStyle(
                    .cyan.opacity(
                        0.72
                    )
                )
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content:
        some View
    {
        if sources.isEmpty
            && isLoadingAddons
        {
            loadingView

        } else if filteredSources
            .isEmpty
        {
            emptyView

        } else {
            sourceList
        }
    }

    private var loadingView:
        some View
    {
        HStack(
            spacing: 16
        ) {
            ProgressView()

            Text(
                "Beschikbare bronnen zoeken…"
            )
            .font(
                .system(
                    size: 22
                )
            )
            .foregroundStyle(
                .white.opacity(
                    0.70
                )
            )
        }
        .padding(
            .top,
            15
        )
    }

    private var emptyView:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: 22
        ) {
            if selectedFilter
                == .iptv
                && isLoadingIPTV
            {
                HStack(
                    spacing: 14
                ) {
                    ProgressView()

                    Text(
                        "IPTV-bronnen worden gezocht…"
                    )
                    .font(
                        .system(
                            size: 23,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        .white.opacity(
                            0.78
                        )
                    )
                }

            } else {
                Text(
                    emptyMessage
                )
                .font(
                    .system(
                        size: 24,
                        weight: .medium
                    )
                )
                .foregroundStyle(
                    .white.opacity(
                        0.78
                    )
                )
            }

            if hasLoaded {
                retryControl
            }
        }
        .padding(
            .top,
            15
        )
    }

    private var emptyMessage:
        String
    {
        switch selectedFilter {
        case .all:
            return
                "Geen afspeelbronnen gevonden."

        case .iptv:
            return
                "Geen IPTV-bronnen gevonden."

        case .origin(
            let name
        ):
            return
                "Geen bronnen gevonden via \(name)."
        }
    }

    // MARK: - Source list

    private var sourceList:
        some View
    {
        ScrollView(
            .vertical,
            showsIndicators: false
        ) {
            LazyVStack(
                alignment: .leading,
                spacing: 18
            ) {
                ForEach(
                    filteredSources
                ) { resolved in
                    sourceRow(
                        resolved
                    )
                }

                if selectedFilter
                    == .all
                    && isLoadingIPTV
                {
                    HStack(
                        spacing: 12
                    ) {
                        ProgressView()
                            .scaleEffect(
                                0.65
                            )

                        Text(
                            "IPTV-bronnen worden nog toegevoegd…"
                        )
                        .font(
                            .system(
                                size: 17
                            )
                        )
                        .foregroundStyle(
                            .white.opacity(
                                0.50
                            )
                        )
                    }
                    .padding(
                        .vertical,
                        12
                    )
                }
            }
            .padding(
                .vertical,
                10
            )
        }
        .focusSection()
    }

    // MARK: - Row

    private func sourceRow(
        _ resolved:
            ResolvedSource
    ) -> some View {
        let source =
            resolved.source

        let isFocused =
            focusedSourceID
                == source.id

        return HStack(
            alignment: .top,
            spacing: 24
        ) {
            sourceIcon(
                source
            )
            .padding(
                .top,
                4
            )

            VStack(
                alignment: .leading,
                spacing: 11
            ) {
                Text(
                    source.name
                )
                .font(
                    .system(
                        size: 27,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    .white
                )
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )

                if let description =
                    source.description?
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        ),
                   !description.isEmpty
                {
                    Text(
                        description
                    )
                    .font(
                        .system(
                            size: 22,
                            weight: .regular
                        )
                    )
                    .foregroundStyle(
                        .white.opacity(
                            0.72
                        )
                    )
                    .lineSpacing(5)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
                    .frame(
                        maxWidth: 900,
                        alignment: .leading
                    )
                }

                Text(
                    sourceFooter(
                        resolved
                    )
                )
                .font(
                    .system(
                        size: 16,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    .cyan.opacity(
                        0.85
                    )
                )
                .padding(
                    .top,
                    2
                )
            }

            Spacer(
                minLength: 24
            )

            Image(
                systemName:
                    "play.fill"
            )
            .font(
                .system(
                    size: 26,
                    weight: .semibold
                )
            )
            .foregroundStyle(
                isFocused
                    ? .white
                    : .cyan
            )
            .padding(
                .top,
                18
            )
        }
        .padding(
            .horizontal,
            26
        )
        .padding(
            .vertical,
            24
        )
        .frame(
            maxWidth: 1200,
            minHeight: 130,
            alignment: .leading
        )
        .background(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .fill(
                isFocused
                    ? Color.cyan
                        .opacity(
                            0.14
                        )
                    : Color.white
                        .opacity(
                            0.035
                        )
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .strokeBorder(
                isFocused
                    ? Color.cyan
                    : Color.cyan
                        .opacity(
                            0.10
                        ),
                lineWidth:
                    isFocused
                    ? 2
                    : 1
            )
        )
        .contentShape(
            Rectangle()
        )
        // Zonder dit wordt de vulling en de rand (`.background`/`.overlay`
        // hierboven) elk apart geschaald door `.scaleEffect` hieronder —
        // op tvOS gaf dat een render-glitch waarbij de linkerrand van de
        // rand (`strokeBorder`) wegviel zodra een bron gefocust werd.
        // `.compositingGroup()` platst kaart + rand eerst tot één laag,
        // die daarna als geheel geschaald wordt.
        .compositingGroup()
        .focusable(true)
        .focused(
            $focusedSourceID,
            equals:
                source.id
        )
        .focusEffectDisabled()
        .scaleEffect(
            isFocused
                ? 1.01
                : 1
        )
        .animation(
            .easeOut(
                duration:
                    0.12
            ),
            value:
                isFocused
        )
        .onTapGesture {
            selectedSource =
                source
        }
    }

    // MARK: - Icon

    private func sourceIcon(
        _ source:
            PlayableSource
    ) -> some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
            .fill(
                Color.cyan
                    .opacity(
                        0.08
                    )
            )

            Image(
                systemName:
                    sourceIconName(
                        source
                    )
            )
            .font(
                .system(
                    size: 32,
                    weight: .medium
                )
            )
            .foregroundStyle(
                .cyan
            )
        }
        .frame(
            width: 72,
            height: 72
        )
    }

    // MARK: - Retry

    private var retryControl:
        some View
    {
        let isFocused =
            retryFocused

        return HStack(
            spacing: 10
        ) {
            Image(
                systemName:
                    "arrow.clockwise"
            )

            Text(
                "OPNIEUW ZOEKEN"
            )
            .font(
                .system(
                    size: 20,
                    weight: .semibold
                )
            )
        }
        .foregroundStyle(
            isFocused
                ? .white
                : .cyan
        )
        .padding(
            .horizontal,
            20
        )
        .padding(
            .vertical,
            13
        )
        .background(
            Capsule()
                .fill(
                    isFocused
                        ? Color.cyan
                            .opacity(
                                0.16
                            )
                        : Color.cyan
                            .opacity(
                                0.06
                            )
                )
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    isFocused
                        ? Color.cyan
                        : Color.cyan
                            .opacity(
                                0.18
                            ),
                    lineWidth:
                        isFocused
                        ? 2
                        : 1
                )
        )
        .contentShape(
            Capsule()
        )
        .focusable(true)
        .focused(
            $retryFocused
        )
        .focusEffectDisabled()
        .onTapGesture {
            reloadID =
                UUID()
        }
    }

    // MARK: - Load

    private func loadSources()
        async
    {
        sources = []

        hasLoaded =
            false

        selectedFilter =
            .all

        isLoadingAddons =
            true

        isLoadingIPTV =
            false

        // Addons en mediaservers (bv. VeyraHub/Jellyfin) tegelijk ophalen —
        // allebei zijn "origin"-bronnen die als eigen filterknop verschijnen.
        async let addonValuesTask =
            resolver.addonSources(
                for: item
            )

        async let mediaServerValuesTask =
            resolver.jellyfinSources(
                for: item
            )

        let (
            addonValues,
            mediaServerValues
        ) = await (
            addonValuesTask,
            mediaServerValuesTask
        )

        guard
            !Task.isCancelled
        else {
            return
        }

        sources =
            SourceResolver
                .deduplicated(
                    addonValues
                        + mediaServerValues
                )

        isLoadingAddons =
            false

        // IPTV voor films én series.
        isLoadingIPTV =
            true

        let iptvValues =
            await resolver
                .iptvSources(
                    for: item
                )

        guard
            !Task.isCancelled
        else {
            return
        }

        sources =
            SourceResolver
                .deduplicated(
                    sources
                        + iptvValues
                )

        isLoadingIPTV =
            false

        hasLoaded =
            true
    }

    // MARK: - Labels

    private var mediaDescription:
        String
    {
        switch item.type {
        case .movie:
            return
                "Beschikbare filmbronnen"

        case .series:
            if let season =
                item.seasonNumber,
               let episode =
                item.episodeNumber
            {
                return
                    "Seizoen \(season) · Aflevering \(episode)"
            }

            return
                "Beschikbare seriebronnen"

        case .liveTV, .iptvSeries:
            return
                "Beschikbare livebron"
        }
    }

    private func sourceFooter(
        _ resolved:
            ResolvedSource
    ) -> String {
        if resolved.source.kind
            == .iptvVOD
        {
            return
                "IPTV VOD"
        }

        // Naast de addonnaam ook vermelden dat dit via VeyraHub loopt, zo
        // blijft dat op elke afzonderlijke kaart zichtbaar — niet alleen in
        // de filterbalk — ook wanneer een lokale addon toevallig dezelfde
        // naam heeft.
        if resolved.isFromHub {
            return
                "\(resolved.originName) · via VeyraHub"
        }

        return
            resolved.originName
    }

    private func sourceIconName(
        _ source:
            PlayableSource
    ) -> String {
        switch source.kind {
        case .iptvVOD:
            return
                "tv.and.hifispeaker.fill"

        case .usenet:
            return
                "externaldrive.fill"

        case .debrid:
            return
                "cloud.fill"

        case .liveTV:
            return
                "antenna.radiowaves.left.and.right"

        case .direct:
            return
                "play.rectangle.fill"
        }
    }
}

#Preview {
    NavigationStack {
        SourceSelectionView(
            item:
                MediaItem(
                    title:
                        "Testfilm",
                    type:
                        .movie,
                    imdbID:
                        "tt0000000",
                    tmdbID:
                        12345,
                    overview:
                        "Test",
                    releaseDate:
                        "2026-09-16"
                )
        )
    }
}
