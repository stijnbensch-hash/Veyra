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
            .frame(maxWidth: 1600)
            .frame(maxWidth: .infinity)
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
        case origin(
            name: String,
            isHub: Bool
        )

        var id: String {
            switch self {
            case .all:
                return "all"

            case .iptv:
                return "iptv"

            case .origin(
                let name,
                let isHub
            ):
                return
                    "origin:\(name):\(isHub)"
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

        // Een addonnaam levert twéé aparte knoppen op zodra er zowel een
        // rechtstreekse (lokaal geïnstalleerde) als een VeyraHub-versie van
        // bestaat — bv. "Usenet" en een apart gestylede "Usenet"-knop via
        // VeyraHub — in plaats van ze onder één knop samen te voegen. Zo
        // blijft meteen zichtbaar welke bronnen via de mediaserver komen.
        var comboSeen =
            Set<String>()

        var combos:
            [(name: String, isHub: Bool)] = []

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

            let key =
                "\(name.lowercased())|\(resolved.isFromHub)"

            guard
                !comboSeen.contains(key)
            else {
                continue
            }

            comboSeen.insert(key)

            combos.append(
                (name: name, isHub: resolved.isFromHub)
            )
        }

        combos.sort {
            let nameOrder =
                $0.name.localizedStandardCompare($1.name)

            if nameOrder != .orderedSame {
                return nameOrder == .orderedAscending
            }

            // Bij gelijke naam komt de gewone addon-knop eerst, de
            // VeyraHub-variant erna.
            return !$0.isHub && $1.isHub
        }

        for combo in combos {
            result.append(
                .origin(
                    name: combo.name,
                    isHub: combo.isHub
                )
            )
        }

        return result
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
            let selectedName,
            let selectedIsHub
        ):
            return sources.filter {
                $0.source.kind
                    != .iptvVOD
                &&
                $0.isFromHub == selectedIsHub
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

    /// Paars/indigo tint voor filterknoppen van bronnen die via VeyraHub
    /// binnenkomen — zelfde opzet als `VeyraFrame`, maar met een duidelijk
    /// andere kleur, zodat zo'n knop meteen herkenbaar is als "komt van de
    /// mediaserver", ook naast een gelijknamige, rechtstreekse addon-knop.
    private static let hubFrameResting = LinearGradient(
        colors: [
            Color(red: 0.62, green: 0.42, blue: 1.0).opacity(0.55),
            .white.opacity(0.10),
            Color(red: 0.38, green: 0.2, blue: 0.85).opacity(0.4),
        ],
        startPoint: .leading, endPoint: .trailing
    )

    private static let hubFrameFill = LinearGradient(
        colors: [
            Color(red: 0.62, green: 0.42, blue: 1.0).opacity(0.30),
            Color(red: 0.62, green: 0.42, blue: 1.0).opacity(0.08),
            Color(red: 0.38, green: 0.2, blue: 0.85).opacity(0.22),
        ],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    private static let hubFrameActive = LinearGradient(
        colors: [
            .white,
            Color(red: 0.72, green: 0.55, blue: 1.0),
            Color(red: 0.46, green: 0.26, blue: 0.95).opacity(0.85),
        ],
        startPoint: .leading, endPoint: .trailing
    )

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

        // Een origin-knop bestaat in twee smaken: rechtstreeks van een
        // lokaal geïnstalleerde addon, of via VeyraHub. Die laatste krijgt
        // hier een eigen kleurenschema + hub-icoon + onderschrift, zodat
        // twee knoppen met dezelfde naam (bv. "Usenet" en "Usenet" via
        // VeyraHub) toch meteen uit elkaar te houden zijn.
        let isHubFilter: Bool = {
            if case .origin(_, let isHub) = filter {
                return isHub
            }
            return false
        }()

        return VStack(spacing: 2) {
            HStack(spacing: 8) {
                if isHubFilter {
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

            if isHubFilter {
                Text("VEYRAHUB")
                    .font(
                        .system(
                            size: 11,
                            weight: .bold
                        )
                    )
                    .tracking(1.5)
                    .opacity(0.8)
            }
        }
        .foregroundStyle(.white)
        .padding(
            .horizontal,
            25
        )
        .padding(
            .vertical,
            isHubFilter ? 10 : 13
        )
        .background(
            isHubFilter
                ? (
                    isSelected || isFocused
                        ? AnyShapeStyle(Self.hubFrameFill)
                        : AnyShapeStyle(Color.clear)
                )
                : (
                    isSelected || isFocused
                        ? AnyShapeStyle(VeyraFrame.fill)
                        : AnyShapeStyle(Color.clear)
                ),
            in: Capsule()
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    isHubFilter
                        ? AnyShapeStyle(
                            isSelected || isFocused
                                ? Self.hubFrameActive
                                : Self.hubFrameResting
                        )
                        : AnyShapeStyle(
                            isSelected || isFocused
                                ? VeyraFrame.active
                                : VeyraFrame.resting
                        ),
                    lineWidth:
                        isSelected || isFocused
                        ? 2
                        : 1.5
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
            let name,
            _
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
            let name,
            let isHub
        ):
            return isHub
                ? "Geen bronnen via VeyraHub gevonden voor \(name)."
                : "Geen bronnen gevonden via \(name)."
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
            // Ruimte voor de 1%-`.scaleEffect` bij focus (zie de toelichting
            // bij `sourceRow`'s `.drawingGroup()`) -- zonder deze marge werd
            // de opgeschaalde rand aan beide zijden afgesneden door de
            // `ScrollView`, omdat de kaarten nu vrijwel randvol zijn.
            .padding(
                .horizontal,
                14
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
                        maxWidth: 1300,
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

                let badges = sourceBadges(for: resolved)
                if !badges.isEmpty {
                    HStack(spacing: 10) {
                        ForEach(badges) { badge in
                            sourceBadgeChip(badge)
                        }
                    }
                    .padding(.top, 4)
                }
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
            maxWidth: 1600,
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
        // `.compositingGroup()` platte de laag alleen samen voor blending;
        // dat bleek niet genoeg om de rand ook echt als één bitmap mee te
        // schalen -- `.drawingGroup()` rasteriseert kaart + rand vooraf tot
        // één afbeelding, die daarna zonder randartefacten geschaald wordt.
        .drawingGroup()
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

    private func sourceBadges(for resolved: ResolvedSource) -> [SourceBadge] {
        SourceBadgeStore.shared.badges(matching: [
            resolved.originName,
            resolved.source.providerName ?? "",
            resolved.source.name,
            resolved.source.description ?? ""
        ])
    }

    /// De pil-achtergrond/rand (`tagColor`/`borderColor`) hoort bij de badge
    /// zelf, niet alleen bij de tekst-terugval — een geladen afbeelding komt
    /// dus ook binnenin dezelfde pil te zitten, net als in het bronpakket
    /// bedoeld is (`tagStyle`: "filled and bordered" / "bordered").
    private func sourceBadgeChip(_ badge: SourceBadge) -> some View {
        sourceBadgeChipContent(badge)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(Color(sourceBadgeHex: badge.tagColor) ?? VeyraColors.cyan.opacity(0.6))
            )
            .overlay(
                Capsule().strokeBorder(Color(sourceBadgeHex: badge.borderColor) ?? .clear, lineWidth: 1.5)
            )
    }

    @ViewBuilder
    private func sourceBadgeChipContent(_ badge: SourceBadge) -> some View {
        if let imageURL = badge.imageURL {
            AsyncImage(url: imageURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                } else {
                    sourceBadgeFallback(badge)
                }
            }
            .frame(height: 26)
        } else {
            sourceBadgeFallback(badge)
        }
    }

    private func sourceBadgeFallback(_ badge: SourceBadge) -> some View {
        Text(badge.name)
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(Color(sourceBadgeHex: badge.textColor) ?? .white)
    }

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

    /// Herschikt bronnen volgens de door de gebruiker ingestelde
    /// bronvolgorde (Instellingen → Bronnen → Bronverschijning →
    /// Bronvolgorde) — bepaalt zowel de volgorde in "Alle" als de volgorde
    /// van de losse filterknoppen (die worden immers uit `sources`
    /// afgeleid, in ditzelfde volgorde).
    private static func applyOriginOrder(
        _ values: [ResolvedSource]
    ) -> [ResolvedSource] {
        SourceOrderDefaults.sortedByOriginOrder(
            values,
            order: SourceOrderDefaults.loadOriginOrder(),
            originName: { $0.originName },
            isFromHub: { $0.isFromHub }
        )
    }

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

        #if DEBUG
        print(
            "[SourceSelectionView] addons=\(addonValues.count) mediaServer=\(mediaServerValues.count) (\(mediaServerValues.filter(\.isFromHub).count) via hub)"
        )
        #endif

        sources =
            Self.applyOriginOrder(
                SourceResolver
                    .deduplicated(
                        addonValues
                            + mediaServerValues
                    )
            )

        #if DEBUG
        print(
            "[SourceSelectionView] na merge: \(sources.count) bronnen (\(sources.filter(\.isFromHub).count) via hub)"
        )
        #endif

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
            Self.applyOriginOrder(
                SourceResolver
                    .deduplicated(
                        sources
                            + iptvValues
                    )
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
